package controller

import (
	"fmt"
	"strings"

	"github.com/QuantumNous/new-api/common"
	"github.com/QuantumNous/new-api/model"
	"github.com/QuantumNous/new-api/setting/system_setting"

	"github.com/gin-gonic/gin"
)

// Desktop launcher endpoints for the FluxGateAI Codex one-click installer.
// Password login returns a dedicated, revocable API key. It never exposes the
// account-wide access token to an installer or bridge client.

const desktopCodexTokenName = "desktop-codex"
const desktopCodexBrand = "FluxGateAI"

type desktopCodexLoginRequest struct {
	Username string `json:"username"`
	Password string `json:"password"`
}

func desktopCodexUserPayload(user *model.User) gin.H {
	return gin.H{
		"id":           user.Id,
		"username":     user.Username,
		"display_name": user.DisplayName,
		"quota":        user.Quota,
		"used_quota":   user.UsedQuota,
		"group":        user.Group,
	}
}

func desktopCodexBaseURL(c *gin.Context) string {
	base := strings.TrimRight(system_setting.ServerAddress, "/")
	// 出厂默认的 http://localhost:3000 是占位值而非真实部署地址：
	// 管理员未配置 ServerAddress 时按请求 Host 推导，避免安装器把
	// localhost 写进用户的 codex 配置。
	if base == "" || base == "http://localhost:3000" {
		scheme := "https"
		if c.Request.TLS == nil && c.GetHeader("X-Forwarded-Proto") != "https" {
			scheme = "http"
		}
		base = scheme + "://" + c.Request.Host
	}
	return base + "/v1"
}

func desktopCodexConnection(c *gin.Context) gin.H {
	return gin.H{
		"base_url":       desktopCodexBaseURL(c),
		"wire_api":       "responses",
		"model_provider": "fluxgate",
		"provider_name":  desktopCodexBrand,
	}
}

func desktopCodexPasswordLoginEnabled() bool {
	return common.PasswordLoginEnabled && !common.TurnstileCheckEnabled
}

// DesktopCodexStatus is a public probe used by the installer before login.
func DesktopCodexStatus(c *gin.Context) {
	common.ApiSuccess(c, gin.H{
		"brand":                  desktopCodexBrand,
		"version":                common.Version,
		"password_login_enabled": desktopCodexPasswordLoginEnabled(),
		"credential_type":        "dedicated_api_key",
		"wire_api":               "responses",
	})
}

// DesktopCodexLogin exchanges username/password for the user's dedicated
// desktop-codex API key. Accounts with 2FA must create a key in the dashboard.
func DesktopCodexLogin(c *gin.Context) {
	c.Header("Cache-Control", "no-store")
	if !desktopCodexPasswordLoginEnabled() {
		if common.TurnstileCheckEnabled {
			common.ApiErrorMsg(c, "站点已启用人机验证，请改用 API Key 模式")
		} else {
			common.ApiErrorMsg(c, "管理员关闭了密码登录，请改用 API Key 模式")
		}
		return
	}
	var req desktopCodexLoginRequest
	if err := common.DecodeJson(c.Request.Body, &req); err != nil {
		common.ApiErrorMsg(c, "无效的参数")
		return
	}
	if req.Username == "" || req.Password == "" {
		common.ApiErrorMsg(c, "用户名或密码不能为空")
		return
	}
	user := model.User{
		Username: req.Username,
		Password: req.Password,
	}
	if err := user.ValidateAndFill(); err != nil {
		common.ApiErrorMsg(c, "用户名或密码错误")
		return
	}
	if user.Status != common.UserStatusEnabled {
		common.ApiErrorMsg(c, "该账号已被禁用")
		return
	}
	if model.IsTwoFAEnabled(user.Id) {
		common.ApiErrorMsg(c, "该账号开启了两步验证，暂不支持桌面端账号登录，请在安装器中改用 API Key 模式")
		return
	}
	var tokens []model.Token
	if err := model.DB.Where("user_id = ? AND name = ?", user.Id, desktopCodexTokenName).
		Order("id ASC").Limit(1).Find(&tokens).Error; err != nil {
		common.ApiError(c, err)
		return
	}
	var desktopToken model.Token
	if len(tokens) > 0 {
		desktopToken = tokens[0]
		if desktopToken.Status != common.TokenStatusEnabled {
			common.ApiErrorMsg(c, fmt.Sprintf("令牌 %s 已被禁用，请到控制台启用后重试", desktopCodexTokenName))
			return
		}
	} else {
		key, err := common.GenerateKey()
		if err != nil {
			common.ApiErrorMsg(c, "生成 API Key 失败，请重试")
			return
		}
		desktopToken = model.Token{
			UserId:         user.Id,
			Key:            key,
			Status:         common.TokenStatusEnabled,
			Name:           desktopCodexTokenName,
			CreatedTime:    common.GetTimestamp(),
			AccessedTime:   common.GetTimestamp(),
			ExpiredTime:    -1,
			UnlimitedQuota: true,
		}
		if err := desktopToken.Insert(); err != nil {
			common.ApiError(c, err)
			return
		}
	}
	model.UpdateUserLastLoginAt(user.Id)
	model.RecordLoginLog(user.Id, user.Username, "Logged in successfully via desktop-codex", c.ClientIP(), "login", map[string]interface{}{
		"method": "desktop-codex",
	}, map[string]interface{}{
		"login_method": "desktop-codex",
		"user_agent":   c.Request.UserAgent(),
	})
	common.ApiSuccess(c, gin.H{
		"api_key":    "sk-" + desktopToken.GetFullKey(),
		"connection": desktopCodexConnection(c),
		"user":       desktopCodexUserPayload(&user),
	})
}
