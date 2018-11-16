zc = zc or {}
helper = helper or {}

--判断一个节点是否可见，如果自身invisible就直接返回false，如果自身visible，就递归寻找它的父节点
function helper.isAllParentsVisible(node)
    local isVisible = true
    while node ~= nil do
        if node:isVisible() == false then
            isVisible = false
            break
        end
        node = node:getParent()
    end
    return isVisible
end

local function _releaseMemory()
    cc.SpriteFrameCache:getInstance():removeUnusedSpriteFrames()
    zc.getDirector():getTextureCache():removeUnusedTextures()
    collectgarbage("collect")
    print("*************清理纹理*************")
end

helper.reloadAllFile = function()
    local _global = package.loaded
    for key, value in pairs(_global) do
        if string.find(tostring(key), "src/") and string.find(tostring(key), ".lua") then
            print("---------------------->"..tostring(key))
            package.loaded[key] = nil;   --赋值为nil的目的是为了重新加载.lua文件，值为true是标记已经加载过了
        end
    end
    --[[异步更新后才需要清除动画的配置文件]]
    _releaseMemory(true)
end

-- 为了尽量不修改引擎源码，在这里做了字符串截取的操作获取当前纹理占用的总内存
helper.getCachedTextureInfo = function()
    local textureCache = cc.Director:getInstance():getTextureCache()
    local memInfo = textureCache:getCachedTextureInfo()
    dump(memInfo)
    local _s = string.find(memInfo, "%(")
    _s = tonumber(_s) or 0
    local _e = string.find(memInfo, "MB)")
    _e = tonumber(_e) or 2
    local ueserMem = string.sub(memInfo, _s + 1, _e - 1)
    ueserMem = tonumber(ueserMem) or 0
    print("----now collectMemory : " .. tostring(ueserMem))
    return ueserMem, memInfo
end

-- 主动释放不用的spriteframe和texture  
-- tip : 请谨慎使用, 小心刚加载，还没被引用就被释放掉得情况出现
helper.collectMemory = function( isForcible, _sNum )
    local memoryTop = tonumber(_sNum) or 70 
    -- 纯纹理内存控制的最大值，大约为实际内存占用量的一半左右，到达则做释放无用纹理处理，可根据做成变量，不同环境具体调整参数
    if isForcible then
        _releaseMemory()
    else
        local ueserMem = helper.getCachedTextureInfo()
        if ueserMem >= memoryTop then
           _releaseMemory()
        end
    end
end


