package hello

// Greet returns a friendly greeting for name.
func Greet(name string) string {
	if name == "" {
		name = "world"
	}
	return "hello, " + name
}
