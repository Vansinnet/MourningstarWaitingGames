local math_random = math.random
local math_abs = math.abs
local math_max = math.max
local math_min = math.min
local math_sqrt = math.sqrt
local math_cos = math.cos
local math_sin = math.sin

local BOARD_W = 600
local BOARD_H = 400
local PADDLE_W = 10
local PADDLE_H = 70
local BALL_SIZE = 12
local PADDLE_SPEED = 350
local MAX_LEVEL = 20
local BASE_SPEED = 150
local LEVEL_SPEED_STEP = 15

local PongGame = {}
PongGame.__index = PongGame

function PongGame:new()
	local g = setmetatable({
		_player_y = BOARD_H / 2,
		_cpu_y = BOARD_H / 2,
		_ball_x = BOARD_W / 2,
		_ball_y = BOARD_H / 2,
		_ball_dx = 0,
		_ball_dy = 0,
		_speed_mult = 1.0,
		_score = 0,
		_cpu_score = 0,
		_level = 1,
		_state = "idle",
	}, PongGame)
	return g
end

function PongGame:start()
	self._player_y = BOARD_H / 2
	self._cpu_y = BOARD_H / 2
	self._ball_x = BOARD_W / 2
	self._ball_y = BOARD_H / 2
	self._speed_mult = 1.0
	self._score = 0
	self._cpu_score = 0
	self._level = 1
	self._state = "playing"
	self:_reset_ball()
end

function PongGame:score() return self._score end
function PongGame:cpu_score() return self._cpu_score end
function PongGame:level() return self._level end
function PongGame:is_game_over() return self._state == "done" end
function PongGame:state() return self._state end
function PongGame:get_player_y() return self._player_y end
function PongGame:get_cpu_y() return self._cpu_y end
function PongGame:get_ball_x() return self._ball_x end
function PongGame:get_ball_y() return self._ball_y end

function PongGame:_reset_ball()
	self._ball_x = BOARD_W / 2
	self._ball_y = BOARD_H / 2
	self._speed_mult = 1.0
	local speed = BASE_SPEED + (self._level - 1) * LEVEL_SPEED_STEP
	local angle = math_random() * 0.6 - 0.3
	self._ball_dx = math_cos(angle) * speed * (math_random() < 0.5 and 1 or -1)
	self._ball_dy = math_sin(angle) * speed
end

function PongGame:move_player(dir, dt)
	if self._state ~= "playing" then return end
	self._player_y = self._player_y + dir * PADDLE_SPEED * (dt or 0.016)
	self._player_y = math_max(PADDLE_H / 2, math_min(BOARD_H - PADDLE_H / 2, self._player_y))
end

function PongGame:update(dt)
	if self._state == "idle" then self._state = "playing"; return end
	if self._state == "done" then return end

	self._ball_x = self._ball_x + self._ball_dx * dt
	self._ball_y = self._ball_y + self._ball_dy * dt

	if self._ball_y <= BALL_SIZE / 2 then
		self._ball_y = BALL_SIZE / 2
		self._ball_dy = math_abs(self._ball_dy)
	elseif self._ball_y >= BOARD_H - BALL_SIZE / 2 then
		self._ball_y = BOARD_H - BALL_SIZE / 2
		self._ball_dy = -math_abs(self._ball_dy)
	end

	if self._ball_x <= PADDLE_W + BALL_SIZE / 2 and self._ball_dx < 0 then
		if math_abs(self._ball_y - self._player_y) < PADDLE_H / 2 + BALL_SIZE / 2 then
			self._ball_x = PADDLE_W + BALL_SIZE / 2
			self._speed_mult = self._speed_mult * 1.1
			local offset = (self._ball_y - self._player_y) / (PADDLE_H / 2)
			local speed = (BASE_SPEED + self._level * LEVEL_SPEED_STEP) * self._speed_mult
			local angle = offset * 0.8
			self._ball_dx = math_cos(angle) * speed
			self._ball_dy = math_sin(angle) * speed
		end
	end

	if self._ball_x >= BOARD_W - PADDLE_W - BALL_SIZE / 2 and self._ball_dx > 0 then
		if math_abs(self._ball_y - self._cpu_y) < PADDLE_H / 2 + BALL_SIZE / 2 then
			self._ball_x = BOARD_W - PADDLE_W - BALL_SIZE / 2
			self._speed_mult = self._speed_mult * 1.1
			local speed = (BASE_SPEED + self._level * LEVEL_SPEED_STEP) * self._speed_mult
			self._ball_dx = -math_abs(self._ball_dx)
			local current_speed = math_sqrt(self._ball_dx * self._ball_dx + self._ball_dy * self._ball_dy)
			if current_speed > 0 then
				self._ball_dy = self._ball_dy / current_speed * speed
			else
				self._ball_dy = math_random() * speed * 0.5 * (math_random() < 0.5 and 1 or -1)
			end
			self._ball_dx = -math_abs(speed)
		end
	end

	if self._ball_x < 0 then
		self._cpu_score = self._cpu_score + 1
		self:_reset_ball()
	elseif self._ball_x > BOARD_W then
		self._score = self._score + 1
		if self._level >= MAX_LEVEL then
			self._state = "done"
			return
		end
		self._level = self._level + 1
		self:_reset_ball()
	end

	self._cpu_think = (self._cpu_think or 0) + dt
	local think_interval = 0.35 - (self._level - 1) * 0.028
	if think_interval < 0.035 then think_interval = 0.035 end

	if self._cpu_think >= think_interval then
		self._cpu_think = 0
		if self._ball_dx > 0 then
			local aim_error_range = math_max(0, 55 - self._level * 5)
			local aim_error = math_random() * aim_error_range * 2 - aim_error_range
			self._cpu_target = self._ball_y + aim_error
		else
			self._cpu_target = BOARD_H / 2
		end
	end

	local cpu_target = self._cpu_target or BOARD_H / 2
	local cpu_speed = 55 + self._level * 30
	local max_move = cpu_speed * dt
	local diff = cpu_target - self._cpu_y
	if math_abs(diff) > max_move then
		diff = (diff > 0 and 1 or -1) * max_move
	end
	self._cpu_y = self._cpu_y + diff
	self._cpu_y = math_max(PADDLE_H / 2, math_min(BOARD_H - PADDLE_H / 2, self._cpu_y))
end

return PongGame
