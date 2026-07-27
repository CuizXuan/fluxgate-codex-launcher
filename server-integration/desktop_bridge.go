package controller

import (
	_ "embed"
	"net/http"
	"net/url"
	"sync"
	"time"

	"github.com/QuantumNous/new-api/common"
	"github.com/QuantumNous/new-api/model"

	"github.com/gin-gonic/gin"
	"github.com/gorilla/websocket"
)

// Desktop Bridge: a phone <-> desktop relay for driving Codex remotely.
//
//   Phone browser (/api/desktop/connect)
//        |  WS /api/desktop/bridge/phone?token=<access_token>
//        v
//   Bridge hub (this file, in-memory, isolated per user)
//        ^
//        |  WS /api/desktop/bridge/device?token=<access_token>&device_id=..&device_name=..
//   Desktop bridge client -> runs `codex exec` in the isolated CODEX_HOME
//
// The hub only relays JSON frames. It never stores Codex/OpenAI credentials,
// and a phone can only reach devices registered under the SAME user id.

const (
	bridgeWriteWait      = 10 * time.Second
	bridgePongWait       = 60 * time.Second
	bridgePingPeriod     = 50 * time.Second
	bridgeMaxMessageSize = 4 << 20 // 4 MiB per frame; the device client chunks large output
	bridgeSendBuffer     = 128
)

var bridgeUpgrader = websocket.Upgrader{
	CheckOrigin:     func(r *http.Request) bool { return true },
	ReadBufferSize:  4096,
	WriteBufferSize: 4096,
}

// bridgeMessage is the on-wire envelope for every frame in both directions.
type bridgeMessage struct {
	Type       string             `json:"type"`
	SessionID  string             `json:"session_id,omitempty"`
	DeviceID   string             `json:"device_id,omitempty"`
	DeviceName string             `json:"device_name,omitempty"`
	Prompt     string             `json:"prompt,omitempty"`
	Cwd        string             `json:"cwd,omitempty"`
	Data       string             `json:"data,omitempty"`
	Stream     string             `json:"stream,omitempty"` // "stdout" | "stderr"
	Message    string             `json:"message,omitempty"`
	ExitCode   *int               `json:"exit_code,omitempty"`
	Devices    []bridgeDeviceInfo `json:"devices,omitempty"`
	Time       int64              `json:"time,omitempty"`
}

type bridgeDeviceInfo struct {
	DeviceID   string `json:"device_id"`
	DeviceName string `json:"device_name"`
	Online     bool   `json:"online"`
}

// bridgeConn wraps a single websocket connection with a serialized writer.
type bridgeConn struct {
	ws         *websocket.Conn
	send       chan []byte
	userID     int
	role       string // "device" | "phone"
	deviceID   string // set for device connections
	deviceName string
	closeOnce  sync.Once
	closed     chan struct{}
}

func (c *bridgeConn) trySend(msg bridgeMessage) {
	b, err := common.Marshal(msg)
	if err != nil {
		return
	}
	select {
	case c.send <- b:
	case <-c.closed:
	default:
		// Slow consumer: drop the connection rather than block the hub.
		c.close()
	}
}

func (c *bridgeConn) close() {
	c.closeOnce.Do(func() {
		close(c.closed)
		_ = c.ws.Close()
	})
}

// bridgeSession links one phone connection to one device connection.
type bridgeSession struct {
	id       string
	userID   int
	deviceID string
	phone    *bridgeConn
	device   *bridgeConn
}

// bridgeSessionKey scopes sessions per account. session_id is chosen by the
// phone client, so a global keyspace would let one account rebind another
// account's live session by guessing (or reusing) its id.
type bridgeSessionKey struct {
	userID    int
	sessionID string
}

type bridgeHub struct {
	mu       sync.RWMutex
	devices  map[int]map[string]*bridgeConn // userID -> deviceID -> device conn
	phones   map[int]map[*bridgeConn]struct{}
	sessions map[bridgeSessionKey]*bridgeSession
}

var hub = &bridgeHub{
	devices:  make(map[int]map[string]*bridgeConn),
	phones:   make(map[int]map[*bridgeConn]struct{}),
	sessions: make(map[bridgeSessionKey]*bridgeSession),
}

func (h *bridgeHub) listDevices(userID int) []bridgeDeviceInfo {
	h.mu.RLock()
	defer h.mu.RUnlock()
	out := make([]bridgeDeviceInfo, 0)
	for id, conn := range h.devices[userID] {
		out = append(out, bridgeDeviceInfo{DeviceID: id, DeviceName: conn.deviceName, Online: true})
	}
	return out
}

func (h *bridgeHub) broadcastDevicesToPhones(userID int) {
	list := h.listDevices(userID)
	h.mu.RLock()
	targets := make([]*bridgeConn, 0, len(h.phones[userID]))
	for p := range h.phones[userID] {
		targets = append(targets, p)
	}
	h.mu.RUnlock()
	for _, p := range targets {
		p.trySend(bridgeMessage{Type: "devices", Devices: list})
	}
}

func (h *bridgeHub) registerDevice(conn *bridgeConn) {
	h.mu.Lock()
	if h.devices[conn.userID] == nil {
		h.devices[conn.userID] = make(map[string]*bridgeConn)
	}
	if old := h.devices[conn.userID][conn.deviceID]; old != nil && old != conn {
		old.close() // replace a stale connection for the same device id
	}
	h.devices[conn.userID][conn.deviceID] = conn
	h.mu.Unlock()
	h.broadcastDevicesToPhones(conn.userID)
}

func (h *bridgeHub) unregisterDevice(conn *bridgeConn) {
	h.mu.Lock()
	if m := h.devices[conn.userID]; m != nil {
		if m[conn.deviceID] == conn {
			delete(m, conn.deviceID)
			if len(m) == 0 {
				delete(h.devices, conn.userID)
			}
		}
	}
	// Tear down sessions bound to this device and notify their phones.
	orphaned := make([]*bridgeSession, 0)
	for key, s := range h.sessions {
		if s.device == conn {
			orphaned = append(orphaned, s)
			delete(h.sessions, key)
		}
	}
	h.mu.Unlock()
	for _, s := range orphaned {
		s.phone.trySend(bridgeMessage{Type: "device_offline", SessionID: s.id, DeviceID: s.deviceID, Message: "设备已离线"})
	}
	h.broadcastDevicesToPhones(conn.userID)
}

func (h *bridgeHub) registerPhone(conn *bridgeConn) {
	h.mu.Lock()
	if h.phones[conn.userID] == nil {
		h.phones[conn.userID] = make(map[*bridgeConn]struct{})
	}
	h.phones[conn.userID][conn] = struct{}{}
	h.mu.Unlock()
}

func (h *bridgeHub) unregisterPhone(conn *bridgeConn) {
	h.mu.Lock()
	if m := h.phones[conn.userID]; m != nil {
		delete(m, conn)
		if len(m) == 0 {
			delete(h.phones, conn.userID)
		}
	}
	// Cancel this phone's sessions on their devices.
	toCancel := make([]*bridgeSession, 0)
	for key, s := range h.sessions {
		if s.phone == conn {
			toCancel = append(toCancel, s)
			delete(h.sessions, key)
		}
	}
	h.mu.Unlock()
	for _, s := range toCancel {
		s.device.trySend(bridgeMessage{Type: "cancel", SessionID: s.id})
	}
}

// routePrompt forwards a phone prompt to the target device, creating the
// session on first use. Returns false if the device is not reachable.
func (h *bridgeHub) routePrompt(phone *bridgeConn, msg bridgeMessage) bool {
	if msg.DeviceID == "" || msg.SessionID == "" {
		return false
	}
	key := bridgeSessionKey{userID: phone.userID, sessionID: msg.SessionID}
	h.mu.Lock()
	device := h.devices[phone.userID][msg.DeviceID]
	if device == nil {
		h.mu.Unlock()
		return false
	}
	s := h.sessions[key]
	if s == nil {
		s = &bridgeSession{id: msg.SessionID, userID: phone.userID, deviceID: msg.DeviceID, phone: phone, device: device}
		h.sessions[key] = s
	} else {
		// Keep the session bound to the latest phone connection.
		s.phone = phone
		s.device = device
	}
	h.mu.Unlock()
	device.trySend(bridgeMessage{Type: "exec", SessionID: msg.SessionID, Prompt: msg.Prompt, Cwd: msg.Cwd})
	return true
}

// routeFromDevice forwards a device frame (output/done/error) back to the phone.
func (h *bridgeHub) routeFromDevice(device *bridgeConn, msg bridgeMessage) {
	key := bridgeSessionKey{userID: device.userID, sessionID: msg.SessionID}
	h.mu.RLock()
	s := h.sessions[key]
	var phone *bridgeConn
	if s != nil && s.device == device {
		phone = s.phone
	}
	h.mu.RUnlock()
	if phone != nil {
		phone.trySend(msg)
	}
	if msg.Type == "done" || msg.Type == "error" {
		h.mu.Lock()
		if cur := h.sessions[key]; cur == s && s != nil {
			delete(h.sessions, key)
		}
		h.mu.Unlock()
	}
}

// routeCancelFromPhone forwards a phone cancel to the bound device.
func (h *bridgeHub) routeCancelFromPhone(phone *bridgeConn, sessionID string) {
	h.mu.RLock()
	s := h.sessions[bridgeSessionKey{userID: phone.userID, sessionID: sessionID}]
	var device *bridgeConn
	if s != nil && s.phone == phone {
		device = s.device
	}
	h.mu.RUnlock()
	if device != nil {
		device.trySend(bridgeMessage{Type: "cancel", SessionID: sessionID})
	}
}

// writePump serializes all writes for a connection and sends periodic pings.
func (c *bridgeConn) writePump() {
	ticker := time.NewTicker(bridgePingPeriod)
	defer func() {
		ticker.Stop()
		c.close()
	}()
	for {
		select {
		case b, ok := <-c.send:
			_ = c.ws.SetWriteDeadline(time.Now().Add(bridgeWriteWait))
			if !ok {
				_ = c.ws.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}
			if err := c.ws.WriteMessage(websocket.TextMessage, b); err != nil {
				return
			}
		case <-ticker.C:
			_ = c.ws.SetWriteDeadline(time.Now().Add(bridgeWriteWait))
			if err := c.ws.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		case <-c.closed:
			return
		}
	}
}

func bridgeAuthUser(c *gin.Context) *model.User {
	token := c.Query("token")
	if token == "" {
		token = c.GetHeader("Authorization")
	}
	if token == "" {
		return nil
	}
	user, err := model.ValidateAccessToken(token)
	if err != nil || user == nil {
		return nil
	}
	if user.Status != common.UserStatusEnabled {
		return nil
	}
	return user
}

func bridgePrepareConn(ws *websocket.Conn) {
	ws.SetReadLimit(bridgeMaxMessageSize)
	_ = ws.SetReadDeadline(time.Now().Add(bridgePongWait))
	ws.SetPongHandler(func(string) error {
		return ws.SetReadDeadline(time.Now().Add(bridgePongWait))
	})
}

// DesktopBridgeDevice handles the desktop client websocket.
func DesktopBridgeDevice(c *gin.Context) {
	user := bridgeAuthUser(c)
	if user == nil {
		c.JSON(http.StatusUnauthorized, gin.H{"success": false, "message": "访问令牌无效"})
		return
	}
	deviceID := c.Query("device_id")
	if deviceID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"success": false, "message": "缺少 device_id"})
		return
	}
	deviceName, _ := url.QueryUnescape(c.Query("device_name"))
	if deviceName == "" {
		deviceName = deviceID
	}
	ws, err := bridgeUpgrader.Upgrade(c.Writer, c.Request, nil)
	if err != nil {
		return
	}
	conn := &bridgeConn{
		ws: ws, send: make(chan []byte, bridgeSendBuffer),
		userID: user.Id, role: "device", deviceID: deviceID, deviceName: deviceName,
		closed: make(chan struct{}),
	}
	bridgePrepareConn(ws)
	hub.registerDevice(conn)
	go conn.writePump()
	conn.trySend(bridgeMessage{Type: "registered", DeviceID: deviceID, Time: common.GetTimestamp()})
	// close() 必须显式调用：读循环退错时若不关 closed 通道，writePump 会一直挂在
	// 半开连接上直到下一次 ping 写失败，goroutine 与 fd 都拖着不放。
	defer conn.close()
	defer hub.unregisterDevice(conn)

	for {
		_, raw, err := ws.ReadMessage()
		if err != nil {
			return
		}
		var msg bridgeMessage
		if common.Unmarshal(raw, &msg) != nil {
			continue
		}
		switch msg.Type {
		case "output", "done", "error":
			hub.routeFromDevice(conn, msg)
		case "ping":
			conn.trySend(bridgeMessage{Type: "pong", Time: common.GetTimestamp()})
		}
	}
}

// DesktopBridgePhone handles the mobile client websocket.
func DesktopBridgePhone(c *gin.Context) {
	user := bridgeAuthUser(c)
	if user == nil {
		c.JSON(http.StatusUnauthorized, gin.H{"success": false, "message": "访问令牌无效"})
		return
	}
	ws, err := bridgeUpgrader.Upgrade(c.Writer, c.Request, nil)
	if err != nil {
		return
	}
	conn := &bridgeConn{
		ws: ws, send: make(chan []byte, bridgeSendBuffer),
		userID: user.Id, role: "phone",
		closed: make(chan struct{}),
	}
	bridgePrepareConn(ws)
	hub.registerPhone(conn)
	go conn.writePump()
	conn.trySend(bridgeMessage{Type: "devices", Devices: hub.listDevices(user.Id)})
	defer conn.close()
	defer hub.unregisterPhone(conn)

	for {
		_, raw, err := ws.ReadMessage()
		if err != nil {
			return
		}
		var msg bridgeMessage
		if common.Unmarshal(raw, &msg) != nil {
			continue
		}
		switch msg.Type {
		case "list_devices":
			conn.trySend(bridgeMessage{Type: "devices", Devices: hub.listDevices(user.Id)})
		case "prompt":
			if !hub.routePrompt(conn, msg) {
				conn.trySend(bridgeMessage{Type: "error", SessionID: msg.SessionID, DeviceID: msg.DeviceID, Message: "目标设备不在线"})
			}
		case "cancel":
			hub.routeCancelFromPhone(conn, msg.SessionID)
		case "ping":
			conn.trySend(bridgeMessage{Type: "pong", Time: common.GetTimestamp()})
		}
	}
}

//go:embed desktop_connect.html
var desktopConnectHTML []byte

// DesktopConnectPage serves the self-contained mobile bridge page.
func DesktopConnectPage(c *gin.Context) {
	c.Data(http.StatusOK, "text/html; charset=utf-8", desktopConnectHTML)
}
