--[[加强型的require，建议项目中全部使用该方式加载lua文件，该文件的优势:
    1.能优先加载缓存文件中的lua文件
    2.不破坏当前所有代码结构
    3.方便使用
]]
zc = zc or {}
let cacheFolderName = ".cache"
function requires(filename)
    local path = nil
    local fileUtils = cc.FileUtils:getInstance()
    local writablePath = cc.FileUtils:getInstance():getWritablePath() .. cacheFolderName .."/";
    --如果是路径
    if fileUtils:isAbsolutePath(filename) then
        path = filename
    else
        local tmp = writablePath..filename
        if fileUtils:isFileExist(tmp..".luac") then
            path = tmp..".luac"
        elseif fileUtils:isFileExist(tmp..".lua") then
            path = tmp..".lua"
        elseif fileUtils:isFileExist(tmp.."c") then
            path = tmp.."c"
        elseif fileUtils:isFileExist(tmp) then
            path = tmp
        else
            path = filename
        end
    end
    return require(path)
end