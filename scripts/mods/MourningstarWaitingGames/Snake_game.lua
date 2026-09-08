local math_random = math.random
local math_floor = math.floor

local GRID = 24
local COLS = 25
local ROWS = 25
local TICK = 0.1

local SnakeGame = {}
SnakeGame.__index = SnakeGame

function SnakeGame:new()
	local g = setmetatable({
		_x = math_floor(COLS / 2) * GRID,
		_y = math_floor(ROWS / 2) * GRID,
		_dx = GRID,
		_dy = 0,
		_cells = {},
		_max_cells = 4,
		_apple_x = 320,
		_apple_y = 320,
		_score = 0,
		_state = "idle",
		_timer = 0,
	}, SnakeGame)
	return g
end

function SnakeGame:start()
	self._x = math_floor(COLS / 2) * GRID
	self._y = math_floor(ROWS / 2) * GRID
	self._dx = GRID
	self._dy = 0
	self._cells = {}
	self._max_cells = 4
	self._score = 0
	self._state = "playing"
	self._timer = 0
	self:_spawn_apple()
end

function SnakeGame:score() return self._score end
function SnakeGame:is_game_over() return self._state == "dead" end
function SnakeGame:state() return self._state end
function SnakeGame:get_apple() return self._apple_x, self._apple_y end
function SnakeGame:get_cells() return self._cells end
function SnakeGame:get_dir() return self._dx, self._dy end

function SnakeGame:_random_col()
	return math_random(0, COLS - 1)
end

function SnakeGame:_random_row()
	return math_random(0, ROWS - 1)
end

function SnakeGame:set_dir(dx, dy)
	if dx ~= 0 and self._dx == 0 then
		self._dx = dx
		self._dy = 0
	elseif dy ~= 0 and self._dy == 0 then
		self._dy = dy
		self._dx = 0
	end
end

function SnakeGame:tick()
	if self._state ~= "playing" then return end

	self._x = self._x + self._dx
	self._y = self._y + self._dy

	if self._x < 0 then self._x = (COLS - 1) * GRID
	elseif self._x >= COLS * GRID then self._x = 0 end
	if self._y < 0 then self._y = (ROWS - 1) * GRID
	elseif self._y >= ROWS * GRID then self._y = 0 end

	table.insert(self._cells, 1, { x = self._x, y = self._y })
	if #self._cells > self._max_cells then
		table.remove(self._cells)
	end

	if self._x == self._apple_x and self._y == self._apple_y then
		self._max_cells = self._max_cells + 1
		self._score = self._score + 1
		self:_spawn_apple()
	end

	local head = self._cells[1]
	for i = 2, #self._cells do
		if head.x == self._cells[i].x and head.y == self._cells[i].y then
			self._state = "dead"
			return
		end
	end
end

function SnakeGame:update(dt)
	if self._state == "idle" then
		self._state = "playing"
		return
	end
	if self._state == "dead" then return end

	self._timer = self._timer + dt
	while self._timer >= TICK do
		self._timer = self._timer - TICK
		self:tick()
	end
end

function SnakeGame:_spawn_apple()
	local occupied = {}
	for _, c in ipairs(self._cells) do
		occupied[c.x .. "," .. c.y] = true
	end
	occupied[self._x .. "," .. self._y] = true
	for i = 1, 200 do
		local ax = self:_random_col() * GRID
		local ay = self:_random_row() * GRID
		if not occupied[ax .. "," .. ay] then
			self._apple_x = ax
			self._apple_y = ay
			return
		end
	end
	self._apple_x = self:_random_col() * GRID
	self._apple_y = self:_random_row() * GRID
end

return SnakeGame
