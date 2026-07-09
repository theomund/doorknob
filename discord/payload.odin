package discord

Hello :: struct {
	heartbeat_interval: uint,
}

Data :: union {
	Hello,
	uint
}

Operation :: enum {
	Heartbeat = 1,
	Hello = 10,
	Heartbeat_Ack = 11
}

Event :: struct {
	op: Operation,
	d:  Data,
	s:  Maybe(uint),
	t:  Maybe(string),
}
