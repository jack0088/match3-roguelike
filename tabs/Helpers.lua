-- Collection of useful functions and extensions for Codea
-- Version 1.6 (April 2017)
-- Copyright (c) by kontakt@herrsch.de


-- PICO-8 color palette
colorPico8 = {
    color(0, 0, 0, 255),
    color(29, 43, 83, 255),
    color(126, 37, 83, 255),
    color(0, 135, 81, 255),
    color(171, 82, 54, 255),
    color(95, 87, 79, 255),
    color(194, 195, 199, 255),
    color(255, 241, 232, 255),
    color(255, 0, 77, 255),
    color(255, 163, 0, 255),
    color(255, 236, 39, 255),
    color(0, 228, 54, 255),
    color(41, 173, 255, 255),
    color(131, 118, 156, 255),
    color(255, 119, 168, 255),
    color(255, 204, 170, 255),
    color(255, 255, 255, 255)
}

colorPico8.black = colorPico8[1]
colorPico8.dark_blue = colorPico8[2]
colorPico8.dark_purple = colorPico8[3]
colorPico8.dark_green = colorPico8[4]
colorPico8.brown = colorPico8[5]
colorPico8.dark_gray = colorPico8[6]
colorPico8.light_gray = colorPico8[7]
colorPico8.light_white = colorPico8[8]
colorPico8.red = colorPico8[9]
colorPico8.orange = colorPico8[10]
colorPico8.yellow = colorPico8[11]
colorPico8.green = colorPico8[12]
colorPico8.blue = colorPico8[13]
colorPico8.indigo = colorPico8[14]
colorPico8.pink = colorPico8[15]
colorPico8.peach = colorPico8[16]
colorPico8.white = colorPico8[17]


-- Codea's Orientation Handler (rewritten). Now this callback fires only if something really changed.
-- displayMode also triggers this event!
-- If displayMode is provided before(!) setup() then Codea knows its screen size upfront and doesn't call this callback before setup
-- If displayMode isn't provided at all or...
-- If displayMode is provided inside(!) setup() then Codea doesn't know its final screen size and will fire this callback after setup
-- When reload button clicked there are no more orientationChanged() calls because Codea caches results from above
do
    local _orientationChanged = orientationChanged or function() end
    local portrait = table.concat({PORTRAIT, PORTRAIT_UPSIDE_DOWN, PORTRAIT_ANY}, ",")
    local landscape = table.concat({LANDSCAPE_LEFT, LANDSCAPE_RIGHT, LANDSCAPE_ANY}, ",")
    local prevOrientation = CurrentOrientation
    local prevWidth = WIDTH
    local prevHeight = HEIGHT
    
    local function name(orientation)
        if portrait:find(orientation) then return "PORTRAIT"
        else return "LANDSCAPE" end
    end
    
    local function screen()
        return {
            prevOrientation = prevOrientation,
            currOrientation = CurrentOrientation,
            prevOrientationName = name(prevOrientation),
            currOrientationName = name(CurrentOrientation),
            prevWidth = prevWidth,
            currWidth = WIDTH,
            prevHeight = prevHeight,
            currHeight = HEIGHT
        }
    end
    
    function orientationChanged()
        if prevWidth ~= WIDTH or prevHeight ~= HEIGHT then -- device rotated 90°
            _orientationChanged(screen())
            prevOrientation = CurrentOrientation
            prevWidth = WIDTH
            prevHeight = HEIGHT
        elseif prevOrientation ~= CurrentOrientation then
            if (landscape:find(CurrentOrientation) and landscape:find(prevOrientation)) -- device rotated 180°
            or (portrait:find(CurrentOrientation) and portrait:find(prevOrientation))
            then
                _orientationChanged(screen())
                prevOrientation = CurrentOrientation
            end
        end
    end
end


-- (Rewritten) Codea's Multitouch Handler for better control and more options
do
    local touches = {}
    local expiredTouches = 0
    local gestureCountdown = .08 -- ADJUST!
    local touchesAutoDispatcher
    local dispatchTouches = touched or function() end
    RESTING = 3 -- new global touch state
    
    function touched(touch)
        -- Identify touch
        local gesture, uid = #touches > 0 and touches[1].initTime + gestureCountdown < ElapsedTime
        for r, t in ipairs(touches) do
            if touch.id == t.id then uid = r end
            touches[r].state = RESTING
        end
        
        -- Cache updates
        local rt = touches[uid] or {}
        local template = {
            id = rt.id or touch.id,
            state = touch.state,
            tapCount = CurrentTouch.tapCount,
            initTime = rt.initTime or ElapsedTime,
            duration = ElapsedTime - (rt.initTime or ElapsedTime),
            initX = rt.initX or touch.x,
            initY = rt.initY or touch.y,
            x = touch.x,
            y = touch.y,
            prevX = touch.prevX,
            prevY = touch.prevY,
            deltaX = touch.deltaX,
            deltaY = touch.deltaY,
            radius = touch.radius,
            radiusTolerance = touch.radiusTolerance,
            force = remapRange(touch.radius, 0, touch.radius + touch.radiusTolerance, 0, 1)
        }
        
        if uid then
            -- Update touches
            touches[uid] = template
            
            -- Dispatch touches
            if touch.state == ENDED then
                -- First touch expired while gesture still active (or waiting to get active)
                if expiredTouches == 0 then
                    -- Gesture was waiting to get active
                    if touchesAutoDispatcher then
                        -- Sync all touch states to BEGAN
                        -- Still dispatch the planed BEGAN state from Auto-Dispatch
                        for r, t in ipairs(touches) do
                            touches[r].state = BEGAN
                            touches[r].initX = t.x
                            touches[r].initY = t.y
                        end
                        dispatchTouches(table.unpack(touches))
                        
                        -- Cancel gesture!
                        tween.reset(touchesAutoDispatcher)
                        touchesAutoDispatcher = nil
                    end
                    
                    -- Sync all touch states to ENDED
                    for r, t in ipairs(touches) do
                        touches[r].state = ENDED
                    end
                    -- Dispatch ENDED
                    dispatchTouches(table.unpack(touches))
                end
                
                -- Delete all touches when all expired
                expiredTouches = expiredTouches + 1
                if expiredTouches == #touches then
                    touches = {}
                    expiredTouches = 0
                end
            else
                -- Dispatch MOVING
                if not touchesAutoDispatcher and gesture and expiredTouches == 0 then
                    dispatchTouches(table.unpack(touches))
                end
            end
        else
            -- Register touch
            -- Ignore new touches when gesture already active
            if not gesture and touch.state == BEGAN then
                table.insert(touches, template)
                uid = #touches
                
                -- Auto-Dispatch touches
                if uid == 1 then
                    -- Dispatch BEGAN ... when gesture gets active
                    touchesAutoDispatcher = tween.delay(gestureCountdown, function()
                        -- Sync all touch states to BEGAN
                        for r, t in ipairs(touches) do
                            touches[r].state = BEGAN
                            touches[r].initX = t.x
                            touches[r].initY = t.y
                        end
                        -- Dispatch BEGAN
                        dispatchTouches(table.unpack(touches))
                        touchesAutoDispatcher = nil
                    end)
                end
            end
        end
    end
end


-- Codea API extention to detect device shaking events
-- Codea API extension to execute commands in sequence
do
    local thread_queue = {}
    local _draw = draw
    local eventTimer = .3 -- listener lifetime
    local intensity = 1.0 -- min. shake intensity to trigger this event
    local shakeEventBeganAt
    local shakeEventUpdatedAt
    
    -- Run scripted sequence of commands in sequence
    -- Use: exec(wait, 1) exec(print, "waited")
    function thread_update()
        if #thread_queue > 0 then
            if coroutine.status(thread_queue[1]) == "dead" then table.remove(thread_queue, 1)
            else coroutine.resume(thread_queue[1], thread_queue[1]) end
        end
    end
    
    function exec(func, ...)
        local params = {...}
        local thread = function(self) func(self, unpack(params)) end
        table.insert(thread_queue, coroutine.create(thread))
    end
    
    function wait(self, time)
        local term = ElapsedTime + time
        while ElapsedTime <= term do
            if type(self) == "thread" then
                coroutine.yield()
            end
        end
    end
    
    -- Rewrite Codea's draw method to support additional API
    function draw()
        if UserAcceleration.x > intensity or UserAcceleration.y > intensity or UserAcceleration.z > intensity then
            shakeEventUpdatedAt = ElapsedTime
            shakeEventBeganAt = shakeEventBeganAt or shakeEventUpdatedAt
            
            if ElapsedTime - shakeEventBeganAt >= eventTimer then
                -- Provide a deviceShaking() callback function to respond to shake events
                -- just like orientationChanged()
                -- The first rough shake will trigger the listening process
                -- The event handler will then listen next n seconds to see if the shake motion continues
                deviceShaking()
            end
        end
        
        if shakeEventUpdatedAt and ElapsedTime > shakeEventBeganAt + eventTimer then
            shakeEventUpdatedAt = nil
            shakeEventBeganAt = nil
        end
        
        if _draw then
            thread_update()
            _draw()
        end
    end
end


-- Gather uv information about any rectangular region (set of tiles) on a texture
-- Get a sequence of all region-rects from i to j where each sub-region is a tile of width x height
-- The 'explicit'-flag returns only tiles enclosed by the overall region from i to j (skipping the appendices and in-betweens)
-- Regions are described by their index position on texture - reading from top left corner on texture, indices are: 1,2,3...n
-- i and j indices might also be passed as vec2(col, row) which is convenient when spritesheet dimensions grow over time and where sprite indices might shift
function uvTexture(texture, region_width, region_height, i, j, explicit)
    local cols = texture.width / region_width
    local rows = texture.height / region_height
    
    -- Get sprite index from col and row
    local function get_id(cell)
        return (cell.y - 1) * cols + cell.x
    end
    
    -- Get col and row from sprite index
    local function get_cell(id)
        local rem = id % cols
        local col = (rem ~= 0 and rem or cols) - 1
        local row = rows - math.ceil(id / cols)
        return col, row
    end
    
    i = i and (type(i) == "number" and i or get_id(i)) or 1 -- be sure to deal always with number indices
    j = j and (type(j) == "number" and j or get_id(j)) or i
    
    local minCol, minRow = get_cell(i)
    local maxCol, maxRow = get_cell(j)
    local tiles = {}
    local region = {}
    
    -- Collect all tiles enclosed by i and j
    for k = i, j do
        local col, row = get_cell(k)
        local w = 1 / cols
        local h = 1 / rows
        local u = w * col
        local v = h * row
        
        if not explicit
        or (col >= minCol and col <= maxCol)
        then
            table.insert(tiles, {
                id = k, -- region rect index on spritesheet
                col = col + 1, -- example: tile at {col = 1, row = 1}
                row = row + 1, -- would be at the lower left corner, because of OpenGL and Codea convention!
                x = col * region_width, -- {x, y} is the lower left corner position of the tile at {col, row}
                y = row * region_height,
                width = region_width,
                height = region_height,
                uv = {
                    x1 = u,
                    y1 = v,
                    x2 = u + w,
                    y2 = v + h,
                    w = w,
                    h = h
                }
            })
        end
    end
    
    -- Sort tiles by column and row in ascending order
    table.sort(tiles, function(curr, list)
        return curr.row == list.row and curr.col < list.col or curr.row < list.row
    end)
    
    -- Describe the overall region-rect
    local region = {
        x = tiles[1].x,
        y = tiles[1].y,
        width = tiles[#tiles].x + tiles[#tiles].width - tiles[1].x,
        height = tiles[#tiles].y + tiles[#tiles].height - tiles[1].y,
        uv = {
            x1 = tiles[1].uv.x1,
            y1 = tiles[1].uv.y1,
            x2 = tiles[#tiles].uv.x2,
            y2 = tiles[#tiles].uv.y2,
            w = tiles[#tiles].uv.x2 - tiles[1].uv.x1,
            h = tiles[#tiles].uv.y2 - tiles[1].uv.y1
        }
    }
    
    return region, tiles
end


-- Decompose 4x4 matrix into separate transformation operations (translate, rotate, scale)
-- Intended to use with modelMatrix() and viewMatrix()
function matrixDecompose(m)
    local tx = m[13]
    local ty = m[14]
    local tz = m[15]
    local sx = math.sqrt(m[1]^2 + m[2]^2  + m[3]^2)
    local sy = math.sqrt(m[5]^2 + m[6]^2  + m[7]^2)
    local sz = math.sqrt(m[9]^2 + m[10]^2 + m[11]^2)
    -- TODO: extract also z angle in degrees or split further into rx, ry, rz
    return tx, ty, tz, sx, sy, sz
end


-- Choose always bool(bool) over default(bool) while its not nil
function booleanOrDefaultBoolean(bool, default)
    return type(bool) == "nil" and default or bool
end


-- Insert a substring into another string at any position
function stringInsert(str, sub_str, pos)
    pos = pos or #str+1 -- TODO: use UTF8 method
    return  str:sub(1, pos) ..
            sub_str ..
            str:sub(pos+1, #str)
end


-- Extract substrings from string by separator
function stringExtract(str, sep)
    assert(sep, "separator needed")
    local list = {}
    for num in tostring(str):gmatch("[^"..sep.."]+") do
        table.insert(list, num)
    end
    return list
end


-- Similar to table.concat() but concatenates multiple(!) table's values into a new table
-- This is useful if you want to create a new table out of other table's values with the help of unpack()
-- e.g. {unpack(t1), unpack(t2), (t3)} will cut some values and fail doing its job
-- tableConcat(t1, t2, t3) will however unpack and return all values from all tables correctly
function tableConcat(...)
    local dump = {}
    
    local function copy(from, to)
        for _, value in pairs(from) do
            if type(value) == "table" then
                copy(value, to)
            else
                table.insert(to, value)
            end
        end
    end
    
    while #arg > 0 do
        copy(arg[1], dump)
        table.remove(arg, 1)
    end
    
    return dump
end


-- Format the console output of a table
function printf(t, indent)
    if not indent then indent = "" end
    local names = {}
    for n,g in pairs(t) do
        table.insert(names,n)
    end
    table.sort(names)
    for i,n in pairs(names) do
        local v = t[n]
        if type(v) == "table" then
            if v==t then -- prevent endless loop on self reference
                print(indent..tostring(n)..": <-")
            else
                print(indent..tostring(n)..":")
                printf(v,indent.."   ")
            end
        elseif type(v) == "function" then
            print(indent..tostring(n).."()")
        else
            print(indent..tostring(n)..": "..tostring(v))
        end
    end
end


-- Return rotated point around custom origin by certain degree
function rotatePoint(x, y, angle, cx, cy)
    cx = cx or 0
    cy = cy or 0
    local deg = math.rad(angle)
    local sin = math.sin(deg)
    local cos = math.cos(deg)
    return
        cx + (cos*(x-cx) - sin*(y-cy)),
        cy + (sin*(x-cx) + cos*(y-cy))
end


-- Convert point to a percentage value based on given width and height
-- Useful when dynamically positioning objects on screen
function pointRelative(abs_x, abs_y, width, height)
    return abs_x / width, abs_y / height
end


-- Convert point's percentage value back to a point
-- This is the reverse action of pnt_rel()
function pointAbsolute(rel_x, rel_y, width, height)
    return rel_x * width, rel_y * height
end


-- Map value from one range to another
function remapRange(val, a1, a2, b1, b2)
    return b1 + (val-a1) * (b2-b1) / (a2-a1)
end


-- Returns -1 or +1
-- math.random() can generate random values from -n to +n but there is always zero in between these ranges
-- If you just need a positive or negative multiplier then use this function to generate one
function randomSign()
    return 2 * math.random(1, 2) - 3
end


-- This method extends Codea's math class
-- Round number from float to nearest integer based on adjacent delimiter
function roundNumber(float, limit)
    local i, f = math.modf(float)
    return f < limit and math.floor(float) or math.ceil(float)
end


-- Generate 2^n number sequence
-- [start]1, 2, 4, 8, 16, 32, 64, 128, ...[count]
function sequencePower2(count, start)
    local i = math.max(start or 0, 0)
    local j = i + count - 1
    local sequence = {}
    for n = i, j, 1 do
        table.insert(sequence, 2^n)
    end
    return sequence
end


-- Compare given number to array of numbers and return the closest one
function nearestNumber(n, array)
    local curr = array[1]
    for i = 1, #array do
        if math.abs(n - array[i]) < math.abs(n - curr) then
            curr = array[i]
        end
    end
    return curr
end


-- Calculate closest 2^n number to value
function nearestPower2(value)
    return math.log(value) / math.log(2)
end


-- Determine pixel positions on straight line
-- Can be used for A* search algorithm or pixelated line drawings
function bresenham(x1, y1, x2, y2)
    local p1 = vec2(math.min(x1, x2), math.min(y1, y2))
    local p2 = vec2(math.max(x1, x2), math.max(y1, y2))
    local delta = vec2(p2.x - p1.x, p1.y - p2.y)
    local err, e2 = delta.x + delta.y -- error value e_xy
    local buffer = {}
    
    while true do
        e2 = 2 * err
        if #buffer > 0 and buffer[#buffer].y == p1.y then -- increase previous line width
            buffer[#buffer].z = buffer[#buffer].z + 1
        elseif #buffer > 0 and buffer[#buffer].x == p1.x then -- increase previous line height
            buffer[#buffer].w = buffer[#buffer].w + 1
        else -- create new line
            table.insert(buffer, vec4(p1.x, p1.y, 1, 1)) -- image.set(x1, y1)
        end
        if p1.x == p2.x and p1.y == p2.y then break end
        if e2 > delta.y then err = err + delta.y; p1.x = p1.x + 1 end -- e_xy + e_x > 0
        if e2 < delta.x then err = err + delta.x; p1.y = p1.y + 1 end -- e_xy + e_y < 0
    end
    
    return buffer
end


-- Return perpendicular distance from point p0 to line defined by p1 and p2
function perpendicularDistance(p0, p1, p2)
    if p1.x == p2.x then
        return math.abs(p0.x - p1.x)
    end
    
    local m = (p2.y - p1.y) / (p2.x - p1.x) -- slope
    local b = p1.y - m * p1.x -- offset
    local dist = math.abs(p0.y - m * p0.x - b)
    
    return dist / math.sqrt(m*m + 1)
end


-- Curve fitting algorithm
function ramerDouglasPeucker(vertices, epsilon)
    epsilon = epsilon or .1
    local dmax = 0
    local index = 0
    local simplified = {}
    
    -- Find point at max distance
    for i = 3, #vertices do
        local d = perpendicularDistance(vertices[i], vertices[1], vertices[#vertices])
        if d > dmax then
            index = i
            dmax = d
        end
    end
    
    -- Recursively simplify
    if dmax >= epsilon then
        local list1 = {}
        local list2 = {}
        
        for i = 1, index - 1 do table.insert(list1, vertices[i]) end
        for i = index, #vertices do table.insert(list2, vertices[i]) end
        
        local result1 = ramerDouglasPeucker(list1, epsilon)
        local result2 = ramerDouglasPeucker(list2, epsilon)
        
        for i = 1, #result1 - 1 do table.insert(simplified, result1[i]) end
        for i = 1, #result2 do table.insert(simplified, result2[i]) end
    else
        for i = 1, #vertices do table.insert(simplified, vertices[i]) end
    end
    
    return simplified
end


-- Return random point inside a circle
function randomPointInCircle(radius)
    local t = 2 * math.pi * math.random()
    local u = math.random() + math.random()
    local r = u > 1 and (2-u) or u
    return
        radius * r * math.cos(t),
        radius * r * math.sin(t)
end


-- Test point in polygon
function pointInPoly(x, y, poly)
    local oddNodes = false
    local j = #poly
    
    for i = 1, j do
        if (poly[i].y < y and poly[j].y >= y or poly[j].y < y and poly[i].y >= y) and (poly[i].x <= x or poly[j].x <= x) then
            if poly[i].x + (y - poly[i].y) / (poly[j].y - poly[i].y) * (poly[j].x - poly[i].x) < x then
                oddNodes = not oddNodes
            end
        end
        j = i
    end
    
    return oddNodes
end


-- Sort given array of vec2's or {x,y} by x and then by y
function sortArrayVec2(array)
    table.sort(array, function(curr, rem)
        return #char * curr.y + curr.x < #char * rem.y + rem.x
    end)
end


-- Create textured and animated mesh quad
-- Note: available animations are listed as `name = {list of frames as vec2}` pairs
--
-- @params {}:
-- texture: image
-- tilesize: vec2
-- spritesize: vec2
-- position: vec2
-- pivot: vec2 [0-1]
-- animations: {}
-- current_animation: "string"
-- fps: number
-- loop: boolean
-- tintcolor: color()
--
function ssprite(params)
    local quad = mesh()
    local _draw = quad.draw
    
    for name, prop in pairs(params) do
        quad[name] = prop -- copy all params
    end
    
    quad.tintcolor = quad.tintcolor or color(255)
    quad.spritesize = quad.spritesize or quad.tilesize
    quad.position = quad.position or vec2()
    quad.pivot = quad.pivot or vec2()
    quad.current_frame = 1
    quad.fps = quad.fps or 24
    quad.loop = booleanOrDefaultBoolean(quad.loop, true)
    quad:addRect(0, 0, 0, 0)
    
    function quad.draw(self)
        if not self.timer or self.timer <= ElapsedTime then
            local anim = self.animations[self.current_animation]
            local frm = self.current_frame
            local uv = uvTexture(self.texture, self.tilesize.x, self.tilesize.y, anim[frm]).uv
            
            self:setRectTex(1, uv.x1, uv.y1, uv.w, uv.h)
            self.timer = ElapsedTime + 1 / self.fps
            self.current_frame = anim[frm + 1] and frm + 1 or 1
            
            if frm == #anim and not self.loop then
                self.current_frame = frm -- pull back
            end
        end
        
        pushStyle()
        noSmooth()
        pushMatrix()
        translate(self.position.x - self.pivot.x * self.spritesize.x, self.position.y - self.pivot.y * self.spritesize.y)
        self:setColors(self.tintcolor)
        self:setRect(1, self.spritesize.x/2, self.spritesize.y/2, self.spritesize.x, self.spritesize.y)
        _draw(self)
        popMatrix()
        popStyle()
    end
    
    return quad
end
