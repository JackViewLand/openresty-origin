package main

import (
	"net/http"
	"time"
)

func main() {
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("🟢 Go API 正常運作"))
	})

	http.HandleFunc("/login", func(w http.ResponseWriter, r *http.Request) {
		http.SetCookie(w, &http.Cookie{
			Name:     "auth_token",
			Value:    "abc123",
			Path:     "/",
			HttpOnly: true,
			Secure:   false,
			SameSite: http.SameSiteLaxMode,
			Expires:  time.Now().Add(30 * time.Minute),
		})
		w.Write([]byte("✅ 登入成功"))
	})

	http.HandleFunc("/check", func(w http.ResponseWriter, r *http.Request) {
		cookie, err := r.Cookie("auth_token")
		if err != nil || cookie.Value != "abc123" {
			w.WriteHeader(http.StatusForbidden)
			w.Write([]byte("🚫 沒有有效的 Cookie"))
			return
		}
		w.Write([]byte("✅ 已通過 Cookie 驗證"))
	})

	http.ListenAndServe(":5000", nil)
}
