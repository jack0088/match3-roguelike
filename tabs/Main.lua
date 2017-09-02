-- match three roguelike rpg game
-- prototype 1.0


supportedOrientations(PORTRAIT, PORTRAIT_UPSIDE_DOWN)
displayMode(FULLSCREEN)
--displayMode(OVERLAY)


local BOARD_X = 0
local BOARD_Y = 32
local SCALE = HEIGHT / 256
local WAIT = false -- players turn
local spritesheet = readImage("Dropbox:prisonbreak-sprites")
local availableTiles = {
    {
        name = "bomb",
        animations = {idle = {vec2(3, 6), vec2(4, 6)}},
        fps = 12
    },
    {
        name = "saw blade",
        animations = {idle = {vec2(1, 3)}},
        loop = false
    },
    {
        name = "cigarettes",
        animations = {idle = {vec2(2, 3)}},
        loop = false
    },
    {
        name = "golden key",
        animations = {idle = {vec2(3, 3)}},
        loop = false
    },
    {
        name = "razor blade",
        animations = {idle = {vec2(4, 3)}},
        loop = false
    },
    {
        name = "health potion",
        animations = {idle = {vec2(5, 3)}},
        loop = false
    },
    {
        name = "poison potion",
        animations = {idle = {vec2(6, 3)}},
        loop = false
    },
    {
        name = "sickle",
        animations = {idle = {vec2(1, 4)}},
        loop = false
    },
    {
        name = "wall",
        animations = {idle = {vec2(1, 6)}},
        loop = false
    },
    {
        name = "schield",
        animations = {idle = {vec2(1, 5)}},
        loop = false
    },
    {
        name = "skull and bones",
        animations = {idle = {vec2(2, 6)}},
        loop = false
    }
}

local function random_tile(x, y, list, i, j)
    -- TODO: if board already filled then pre-calculate and return randoms that result in possible matches
    i = i or 1
    j = j or #list
    local rnd = list[math.random(i, j)]
    return ssprite{
        texture = spritesheet,
        tilesize = vec2(24, 24),
        spritesize = vec2(18, 18),
        pivot = vec2(.5, .5),
        position = vec2(x, y),
        name = rnd.name or "unnamed ssprite",
        animations = rnd.animations or {idle = {vec2(1, 1)}},
        current_animation = rnd.current_animation or "idle",
        loop = rnd.loop
    }
end


local function generate_board()
    local array = {}
    
    -- Generate random board
    for y = 1, 8 do
        for x = 1, 8 do
            table.insert(array, random_tile(x * 24 - 12, y * 24 - 12, availableTiles))
        end
    end
    
    -- Randomly place player on first row of the board
    local rnd_tile = array[math.random(8)]
    rnd_tile.name = "henry"
    rnd_tile.animations = {
        idle = {vec2(1, 2), vec2(2, 2)},
        attack = {vec2(3, 2), vec2(4, 2)}
    }
    rnd_tile.current_animation = "idle"
    rnd_tile.fps = 3
    rnd_tile.loop = true
    
    return array
end


local function shake_tiles(list, speed, duration)
    -- save positions
    -- setup tweens for shaking each tile
    -- setup tweens for returning to saved positions
end


local function get_tile(x, y)
    local col = math.ceil(x / 24)
    local row = math.ceil(y / 24)
    local id = row * 8 - 8 + col
    return id, col, row
end


local function get_tile_pair(board, touch)
    local src_tile = get_tile(touch.initX, touch.initY)
    local dst_tile = get_tile(touch.x, touch.y)
    local prev_tile = src_tile
    local valid_moves = {
        src_tile - 8, -- bottom
        src_tile - 1, -- left
        src_tile + 1, -- right
        src_tile + 8  -- top
    }
    for i, curr_tile in ipairs(valid_moves) do
        if board[curr_tile] then
            local prev_len = board[prev_tile].position:dist(board[dst_tile].position)
            local curr_len = board[curr_tile].position:dist(board[dst_tile].position)
            if curr_len < prev_len then prev_tile = curr_tile end
        end
    end
    return src_tile, prev_tile
end


local function swap_tiles(board, src_tile, dst_tile, callback)
    tween(.1, board[src_tile].position, {x = board[dst_tile].position.x, y = board[dst_tile].position.y})
    tween(.1, board[dst_tile].position, {x = board[src_tile].position.x, y = board[src_tile].position.y}, tween.easing.linear, callback)
end


local function sort_board(array)
    table.sort(array, function(curr, rem)
        return 192 * curr.position.y + curr.position.x < 192 * rem.position.y + rem.position.x
    end)
end


local function find_matches(board, min_count)
    local search = {}
    
    -- Always sort the board BEFORE checking for matches
    -- otherwise the tile ids will be wrong!
    
    -- Check for horizontal matches
    for y = 1, #board, 8 do
        local namespace, buffer
        
        for x = 0, 7 do
            local curr = x + y
            
            if not namespace or namespace ~= board[curr].name then
                if buffer and #buffer >= min_count then table.insert(search, buffer) end
                buffer = {curr}
                namespace = board[curr].name
            else
                table.insert(buffer, curr)
                if x == 7 and buffer and #buffer >= min_count then table.insert(search, buffer) end
            end
        end
    end
    
    -- Check for vertical matches
    for x = 1, 8 do
        local namespace, buffer = nil, nil
        
        for y = 0, #board - 8, 8 do
            local curr = x + y
            
            if not namespace or namespace ~= board[curr].name then
                if buffer and #buffer >= min_count then table.insert(search, buffer) end
                buffer = {curr}
                namespace = board[curr].name
            else
                table.insert(buffer, curr)
                if y == #board - 8 and buffer and #buffer >= min_count then table.insert(search, buffer) end
            end
        end
    end
    
    return search
end


local function find_moves(board)
    local moves = {}
    
    for _, grp in ipairs(find_matches(board, 2)) do
        if board[grp[1]].position.y == board[grp[#grp]].position.y then
            local scope = { -- neighbour tiles to found grp:
                grp[1] - 2, -- left
                grp[1] - 9, -- left lower
                grp[1] + 7, -- left upper
                grp[#grp] + 2, -- right
                grp[#grp] - 7, -- right lower
                grp[#grp] + 9 -- right upper
            }
            
            for _, ct in ipairs(scope) do -- each current tile
                local ft = grp[1] -- first tile
                local lt = grp[#grp] -- last tile
                
                if board[ct] and board[ft].name == board[lt].name and board[lt].name == board[ct].name then
                    local ft_id, ft_c, ft_r = get_tile(board[ft].position:unpack())
                    local lt_id, lt_c, lt_r = get_tile(board[lt].position:unpack())
                    local ct_id, ct_c, ct_r = get_tile(board[ct].position:unpack())
                    
                    if (ct_r == ft_r and ct_c == ft_c - 2) or ct_c == ft_c - 1 then
                        table.insert(moves, {src_tile = ct_id, dst_tile = ft_id - 1})
                    elseif (ct_r == lt_r and ct_c == lt_c + 2) or ct_c == lt_c + 1 then
                        table.insert(moves, {src_tile = ct_id, dst_tile = lt_id + 1}) end
                end
            end
        else
            local scope = { -- neighbour tiles to found grp:
                grp[1] - 16, -- lower
                grp[1] - 9, -- lower right
                grp[1] - 7, -- lower left
                grp[#grp] + 16, -- upper
                grp[#grp] + 9, -- upper right
                grp[#grp] + 7 -- upper left
            }
            
            for _, ct in ipairs(scope) do -- each current tile
                local ft = grp[1] -- first tile
                local lt = grp[#grp] -- last tile
                
                if board[ct] and board[ft].name == board[lt].name and board[lt].name == board[ct].name then
                    local ft_id, ft_c, ft_r = get_tile(board[ft].position:unpack())
                    local lt_id, lt_c, lt_r = get_tile(board[lt].position:unpack())
                    local ct_id, ct_c, ct_r = get_tile(board[ct].position:unpack())
                    
                    if (ct_c == ft_c and ct_r == ft_r - 2) or ct_r == ft_r - 1 then
                        table.insert(moves, {src_tile = ct_id, dst_tile = ft_id - 8})
                    elseif (ct_c == lt_c and ct_r == lt_r + 2) or ct_r == lt_r + 1 then
                        table.insert(moves, {src_tile = ct_id, dst_tile = lt_id + 8}) end
                end
            end
        end
    end
    
    return moves
end


local function shuffle_board(board, create_moves)
    for i = #board, 1, -1 do
        local j = math.random(i)
        if board[i].name ~= "henry" and board[j].name ~= "henry" then
            board[i].position, board[j].position = board[j].position, board[i].position -- swap instantly
            sort_board(board)
        end
    end
    
    if #find_matches(board, 3) > 0 or #find_moves(board) == 0 then
        shuffle_board(board, create_moves)
    end
end


local function clean_board(board, matches)
    WAIT = true
    local animation = {}
    
    for id, grp in ipairs(matches) do
        
        -- Visually merge matching grp of tiles
        for id = 2, #grp do
            table.insert(animation, tween(.25, board[grp[id]].position, {x = board[grp[1]].position.x, y = board[grp[1]].position.y}, tween.easing.expoOut, function() board[grp[id]].position = vec2(12, 204) end))
            table.insert(animation, tween.delay(.001)) -- NOTE: hack 'layer' to allow tweening different objects in same sequence!
            
            if id == #grp then
                table.insert(animation, tween(.25, board[grp[1]].spritesize, {x = 0, y = 0}, tween.easing.expoOut, function() board[grp[1]].position = vec2(12, 204) end))
                table.insert(animation, tween.delay(.001))
            end
        end
        
        -- Handle horizontal grp of matches
        if string.format("%.0f", board[grp[1]].position.y) == string.format("%.0f", board[grp[#grp]].position.y) then
            
            -- Refill empty rows
            for _, id in ipairs(grp) do
                for r = 1, 8 - select(3, get_tile(board[grp[1]].position:unpack())) do -- loop remaining rows
                    local src_id = id + r * 8
                    local dst_id = src_id - 8
                    
                    table.insert(animation, tween(.05, board[src_id].position, {y = board[dst_id].position.y}, tween.easing.expoOut))
                    table.insert(animation, tween.delay(.001))
                end
                
                table.insert(board, random_tile(board[id].position.x, 204, availableTiles))
                table.insert(animation, tween(.05, board[#board].position, {y = board[#board].position.y - 24}, tween.easing.expoOut))
                table.insert(animation, tween.delay(.001))
            end
        
        -- Handle vertical grp of matches
        else
            
            -- Refill empty column
            for r = 1, 8 - select(3, get_tile(board[grp[#grp]].position:unpack())) do -- loop remaining rows
                local src_id = grp[#grp] + r * 8
                local dst_id = src_id - #grp * 8
                
                table.insert(animation, tween(.05, board[src_id].position, {y = board[dst_id].position.y}, tween.easing.expoOut))
                table.insert(animation, tween.delay(.001))
            end
            
            for i = #grp, 1, -1 do
                table.insert(board, random_tile(board[grp[i]].position.x, 204, availableTiles))
                table.insert(animation, tween(.05, board[#board].position, {y = board[#board].position.y - i * 24}, tween.easing.expoOut))
                table.insert(animation, tween.delay(.001))
            end
            
        end
        
        table.remove(matches, id)
    end
    
    animation[#animation].callback = function()
        -- Remove old tiles from board
        sort_board(board)
        for i = 65, #board do table.remove(board, #board) end
        
        -- Recursevly (re)clean the board
        local matches = find_matches(board, 3)
        if #matches > 0 then
            clean_board(board, matches)
        else
            tween.delay(1, function()
                if #find_moves(board) == 0 then
                    shuffle_board(board, 3)
                    shake_tiles(board)
                end
                WAIT = false
            end)
        end
    end
    
    -- Play complete board animation
    tween.sequence(tween.delay(.1), table.unpack(animation))
end


local function board_touched(board, touch)
    -- Subtract board y-position
    touch.initY = touch.initY - BOARD_Y
    touch.y = touch.y - BOARD_Y
    
    --local tile1, tile2 = get_tile(touch.initX, touch.initY), get_tile(touch.x, touch.y)
    local tile1, tile2 = get_tile_pair(board, touch) -- restrict to nearest tiles
    
    swap_tiles(board, tile1, tile2, function()
        sort_board(board)
        
        local matches = find_matches(board, 3)
        
        if #matches == 0 then
            swap_tiles(board, tile2, tile1, function() sort_board(board) end) -- revert
        else
            clean_board(board, matches) -- start recursive process
        end
    end)
end


function setup()
    -- Generate game board
    repeat level_board = generate_board()
    until #find_matches(level_board, 3) == 0 and #find_moves(level_board) >= 3
    
    -- DEBUG: grid cache
    grid = image(192, 256)
    setContext(grid)
        noSmooth()
        -- Header and footer bg
        noStroke()
        fill(colorPico8.dark_blue)
        rect(0, 224, 192, 32)
        rect(0, 0, 192, 32)
        
        -- Header and footer grid
        ---[[
        strokeWidth(.5)
        stroke(colorPico8.dark_purple)
        line(0, 16, 192, 16)
        line(0, 240, 192, 240)
        for h = 1, 11 do line(h * 16, 0, h * 16, 256) end
        
        -- Board grid
        translate(0, 32)
        noStroke()
        fill(colorPico8.black)
        rect(0, 0, 192, 192)
        strokeWidth(.5)
        stroke(colorPico8.dark_blue)
        --for h = 1, 7 do line(h * 24, 0, h * 24, 192) end
        --for v = 1, 7 do line(0, v * 24, 192, v * 24) end
        --]]
    setContext()
end


function draw()
    background(colorPico8.black)
    ortho(0, 192, 0, 256, -1, 1) -- portrait mode
    noSmooth()
    
    -- DEBUG: grid and profiler
    spriteMode(CORNER)
    sprite(grid)
    
    -- Profiler
    fontSize(6)
    fill(colorPico8.white)
    text(string.format("framerate: %.3fms \nfrequency: %ifps \nmemory: %.0fkb", 1000 * DeltaTime, math.floor(1/DeltaTime), collectgarbage("count")), 96, 16)
    collectgarbage()
    
    -- Board
    translate(BOARD_X, BOARD_Y)
    
    clip(0, 0, WIDTH, HEIGHT - SCALE * BOARD_Y)
        for _, tile in ipairs(level_board) do tile:draw() end
    clip()
    
    
    -- DEBUG: touches
    if CurrentTouch.state == MOVING then
        resetMatrix()
        fill(255, 255, 0, 127)
        ellipse(CurrentTouch.x / SCALE, CurrentTouch.y / SCALE, 8)
    end
end

function touched(touch)
    -- Scale touches to physical screen resolution
    local finger = {
        state = touch.state,
        initX = touch.initX / SCALE,
        initY = touch.initY / SCALE,
        x = touch.x / SCALE,
        y = touch.y / SCALE,
        prevX = touch.prevX / SCALE,
        prevY = touch.prevY / SCALE,
        deltaX = touch.deltaX / SCALE,
        deltaY = touch.deltaY / SCALE
    }
    
    -- Touch inside board
    if not WAIT
    and finger.state == ENDED
    and finger.y > BOARD_Y and finger.y < BOARD_Y + 192
    and finger.initY > BOARD_Y and finger.initY < BOARD_Y + 192
    then
        board_touched(level_board, finger)
    end
end