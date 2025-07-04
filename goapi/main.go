package main

import (
	"encoding/base64"
	"fmt"
	"net/http"
	"strings"
	"time"
)

const (
	validUsername = "admin"
	validPassword = "1234"
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

func protectedHandler(w http.ResponseWriter, r *http.Request) {
	w.Write([]byte("✅ 歡迎！你已通過 Basic 認證"))
}

func basicAuthMiddleware(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		auth := r.Header.Get("Authorization")

		if auth == "" || !strings.HasPrefix(auth, "Basic ") {
			w.Header().Set("WWW-Authenticate", `Basic realm="Restricted"`)
			http.Error(w, "Unauthorized", http.StatusUnauthorized)
			return
		}

		payload, _ := base64.StdEncoding.DecodeString(strings.TrimPrefix(auth, "Basic "))
		pair := strings.SplitN(string(payload), ":", 2)

		if len(pair) != 2 || pair[0] != validUsername || pair[1] != validPassword {
			w.Header().Set("WWW-Authenticate", `Basic realm="Restricted"`)
			http.Error(w, "Invalid credentials", http.StatusUnauthorized)
			return
		}

		next.ServeHTTP(w, r)
	}
}

func main() {
	// 配置路由
	http.HandleFunc("/", rootHandler)
	http.HandleFunc("/cookie/login", cookieLoginHandler)
	http.HandleFunc("/cookie/logout", cookieLogoutHandler)
	http.HandleFunc("/cookie/check", cookieCheckHandler)
	http.HandleFunc("/admin", basicAuthMiddleware(protectedHandler))

	http.ListenAndServe(":5000", nil)
	fmt.Println("Go api server running at :5000")
}
