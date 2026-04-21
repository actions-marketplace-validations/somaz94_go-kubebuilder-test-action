package hello

import "testing"

func TestGreet(t *testing.T) {
	cases := []struct {
		in, want string
	}{
		{"world", "hello, world"},
		{"", "hello, world"},
		{"kubebuilder", "hello, kubebuilder"},
	}
	for _, c := range cases {
		if got := Greet(c.in); got != c.want {
			t.Errorf("Greet(%q) = %q; want %q", c.in, got, c.want)
		}
	}
}
