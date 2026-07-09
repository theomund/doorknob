package discord

Hello :: struct {
	heartbeat_interval: uint,
}

Data :: union {
	Hello,
}

Operation :: enum {
	Hello = 10,
}

Event :: struct {
	op: Operation,
	d:  Data,
	s:  Maybe(uint),
	t:  string,
}
