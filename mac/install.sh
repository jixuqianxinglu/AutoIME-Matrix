#!/bin/bash

echo "🚀 开始一键部署 Hammerspoon 输入法智能切换环境..."

# 获取脚本当前所在的目录
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# 1. 环境检查
if [ ! -d "$DIR/Hammerspoon.app" ]; then
    echo "❌ 错误：未找到 Hammerspoon.app！"
    echo "请确保你将此脚本与 Hammerspoon.app 放在同一个文件夹下。"
    exit 1
fi

# 2. 安装应用 (静默覆盖安装)
echo "📦 正在安装 Hammerspoon 到应用程序文件夹..."
cp -R "$DIR/Hammerspoon.app" /Applications/

# 3. 创建并写入配置文件
echo "📂 正在配置 Lua 脚本..."
mkdir -p ~/.hammerspoon

cat << 'EOF' > ~/.hammerspoon/init.lua
-- ==========================================
-- 1. 需要强制纯英文的应用名单
-- ==========================================
local englishApps = {
    -- 终端工具
    ["XTerminal"] = true, ["Terminal"] = true, ["终端"] = true,["iTerm2"] = true, ["Warp"] = true,
    ["Tabby"] = true, ["Alacritty"] = true, ["kitty"] = true,
    
    -- 编辑器与 IDE
    ["Code"] = true, ["Cursor"] = true, ["Zed"] = true, ["Sublime Text"] = true,
    ["IntelliJ IDEA"] = true, ["PyCharm"] = true, ["WebStorm"] = true,
    ["GoLand"] = true, ["CLion"] = true, ["Android Studio"] = true, ["Xcode"] = true,
    
    -- 测试与数据库
    ["Postman"] = true, ["Apifox"] = true, ["Insomnia"] = true,
    ["Charles"] = true, ["Proxyman"] = true, ["Wireshark"] = true,
    ["Navicat Premium"] = true, ["DataGrip"] = true, ["DBeaver"] = true,
    ["Sequel Ace"] = true, ["TablePlus"] = true, ["RedisInsight"] = true,
    
    -- 版本控制与系统工具
    ["SourceTree"] = true, ["Fork"] = true, ["GitHub Desktop"] = true,
    ["Tower"] = true, ["Docker"] = true, ["OrbStack"] = true,
    ["Activity Monitor"] = true, ["Console"] = true, ["Keychain Access"] = true,
    
    -- 远程协作与设计
    ["Termius"] = true, ["Royal TSX"] = true, ["SecureCRT"] = true,
    ["Microsoft Remote Desktop"] = true, ["Core Shell"] = true,
    ["Raycast"] = true, ["Alfred"] = true, ["Figma"] = true, ["Sketch"] = true
}

local englishIM = "com.apple.keylayout.ABC"
local previousIM = nil -- 核心：用于记忆切入终端前的系统全局输入法状态

-- ==========================================
-- 2. 智能记忆与恢复逻辑 (防崩溃保护版)
-- ==========================================
function applicationWatcher(appName, eventType, appObject)
    if (eventType == hs.application.watcher.activated) then
        -- 判空保护，防止幽灵进程崩溃
        if not appName then return end

        -- 场景 A：切入开发软件
        if englishApps[appName] then
            local currentIM = hs.keycodes.currentSourceID()
            -- 如果当前不是英文，说明是刚从外边切进来的，存下状态并强切英文
            if currentIM ~= englishIM then
                previousIM = currentIM 
                hs.keycodes.currentSourceID(englishIM)
            end
        
        -- 场景 B：切入非开发软件 (微信、浏览器等)
        else
            -- 如果口袋里有记忆的状态，说明刚离开开发环境，立刻恢复它
            if previousIM then
                hs.keycodes.currentSourceID(previousIM)
                previousIM = nil -- 恢复完清空记忆
            end
        end
    end
end

-- 启动监听
appWatcher = hs.application.watcher.new(applicationWatcher)
appWatcher:start()

-- 加载提示
hs.alert.show("⌨️ 输入法全局智能切换已就绪")
EOF

# 4. 启动应用
echo "✅ 部署完成！正在为你启动 Hammerspoon..."
open -a Hammerspoon

echo "------------------------------------------------------"
echo "⚠️  最后一步（必须手动完成）："
echo "1. 在弹出的设置窗口勾选【Launch Hammerspoon at login】(开机自启)。"
echo "2. 请在弹出的提示框，或点击顶部状态栏的小锤子图标 -> Preferences -> 点击底部的 'Enable Accessibility' 进行系统授权！"
echo "（无需更改 macOS 其他键盘设置，畅享全局智能恢复！）"
echo "------------------------------------------------------"