# FluxGateAI/new-api integration

These files are the server-side portion used by the public launcher and mobile Bridge:

- `desktop_codex.go`: status, login and dedicated API-key endpoints.
- `desktop_bridge.go`: authenticated device/phone WebSocket relay and embedded mobile page handler.
- `desktop_connect.html`: the exact self-contained mobile page embedded by `desktop_bridge.go`.

Copy the files into the `controller/` package of a compatible FluxGateAI/new-api checkout and register these routes:

```go
bridgeRouter := router.Group("/api/desktop/bridge")
bridgeRouter.GET("/device", controller.DesktopBridgeDevice)
bridgeRouter.GET("/phone", controller.DesktopBridgePhone)

apiRouter.GET("/desktop/connect", controller.DesktopConnectPage)
apiRouter.GET("/desktop/codex/status", controller.DesktopCodexStatus)
apiRouter.POST("/desktop/codex/login", controller.DesktopCodexLogin)
apiRouter.GET("/desktop/codex/token", controller.DesktopCodexToken)
```

The code retains its FluxGateAI/new-api and QuantumNous package attribution. It is distributed under the repository license in the root `LICENSE` file.
