package main

import (
	"net/http"
	"time"
)

func rootHandler(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	w.Write([]byte("🟢 Go API 正常運作"))
}

func cookieLoginHandler(w http.ResponseWriter, r *http.Request) {
	http.SetCookie(w, &http.Cookie{
		Name:     "auth_token",
		Value:    "jack_test",
		Path:     "/",
		HttpOnly: true,
		Secure:   false,
		SameSite: http.SameSiteLaxMode,
		Expires:  time.Now().Add(30 * time.Minute),
	})
	w.Write([]byte("✅ 登入成功"))
}

func cookieLogoutHandler(w http.ResponseWriter, r *http.Request) {
	http.SetCookie(w, &http.Cookie{
		Name:     "auth_token",
		Value:    "",
		Path:     "/",
		MaxAge:   -1, // 移除 cookie
		HttpOnly: true,
	})
	w.Write([]byte("👋 已登出"))
}

func cookieCheckHandler(w http.ResponseWriter, r *http.Request) {
	cookie, err := r.Cookie("auth_token")
	if err != nil || cookie.Value != "jack_test" {
		w.WriteHeader(http.StatusForbidden)
		w.Write([]byte("🚫 沒有有效的 Cookie"))
		return
	}
	w.Write([]byte("✅ 已通過 Cookie 驗證: " + cookie.Value))
}

func main() {
	// 配置路由
	http.HandleFunc("/", rootHandler)
	http.HandleFunc("/cookie/login", cookieLoginHandler)
	http.HandleFunc("/cookie/logout", cookieLogoutHandler)
	http.HandleFunc("/cookie/check", cookieCheckHandler)

	http.ListenAndServe(":5000", nil)
}
