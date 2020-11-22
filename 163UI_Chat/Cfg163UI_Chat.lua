U1_CHAT_WORLD_CHANNEL = "大脚世界频道";
local exampleTime = time({ year = 2010, month = 12, day = 15, hour = 15, min = 27, sec = 32, })
local tsFormat = { TIMESTAMP_FORMAT_HHMM, TIMESTAMP_FORMAT_HHMMSS, TIMESTAMP_FORMAT_HHMM_AMPM, TIMESTAMP_FORMAT_HHMMSS_AMPM, TIMESTAMP_FORMAT_HHMM_24HR, TIMESTAMP_FORMAT_HHMMSS_24HR }
local tsOptions = { "不改变暴雪样式", "", "无", "none", } for _, v in ipairs(tsFormat) do tinsert(tsOptions, BetterDate(v, exampleTime)); tinsert(tsOptions, v) end

U1RegisterAddon("163UI_Chat", {
    title = "聊天增强",
    defaultEnable = 1,
    load = "LOGIN",
    desc = "和聊天框相关的小插件，提供聊天框缩放、鼠标滚轮增强、TAB切换频道、点击时间标记复制文本等功能，详情参见设置页面。` `此外还整合了'自动查询密语详情'及'智能切换声望条'的功能。",

    tags = { TAG_CHAT, TAG_DEV },

    --icon = [[Interface\Icons\Achievement_WorldEvent_ChildrensWeek]],
    author = "|cffcd1a1c[爱不易原创]|r",
    icon = [[Interface\Icons\Spell_Holy_HolyGuidance]],
    ------- Options --------
    {
        var="worldchannel",
        default = false,
        text="加入世界频道",
        callback = function(cfg, v, loading)
            if v then
                local id, name = JoinChannelByName(U1_CHAT_WORLD_CHANNEL)
                if not id then
                    CoreOnEvent("INITIAL_CLUBS_LOADED", function()
                        JoinChannelByName(U1_CHAT_WORLD_CHANNEL)
                        return true
                    end)
                end
            else
                LeaveChannelByName(U1_CHAT_WORLD_CHANNEL)
            end
            if DuowanChat and DuowanChat.SetBFChannelMuted and dwChannel_RefreshMuteButton then
                DuowanChat:SetBFChannelMuted(not v)
                dwChannel_RefreshMuteButton()
            end
        end,
    },

    {
        var="wwm",
        default = false,
        text="自动查询密我的人是谁",
        callback = function(cfg, v, loading)
            WhoWhisperedMeCmds(v and "ON" or "OFF");
        end,
        {
            text="列出密我的所有人",
            tip="说明`可以点击回复哦`命令行：/wwm",
            callback = function() WhoWhisperedMeCmds("stats") end,
        }
    },
    {
        var = "whispersticky",
        default = false,
        type = "checkbox",
        text = "保持上次密语对象",
        tip = "说明`按回车时显示的是最近一次密语的人，容易密错人，请注意哦。",
        callback = function(cfg, v, loading)
            ChatTypeInfo["WHISPER"].sticky = v and 1 or 0;
            ChatTypeInfo["BN_WHISPER"].sticky = v and 1 or 0;
            if not v then
                WithAllChatFrame(function(cf)
                    local ctype = cf.editBox:GetAttribute("chatType")
                    if ctype=="WHISPER" or ctype=="BN_WHISPER" then
                        cf.editBox:SetAttribute("chatType", "SAY")
                    end
                    local stype = cf.editBox:GetAttribute("stickyType")
                    if stype=="WHISPER" or stype=="BN_WHISPER" then
                        cf.editBox:SetAttribute("stickyType", "SAY")
                    end
                end)
            end
        end,
    },
    {
        var = "resize2",
        default = 1,
        type = "checkbox",
        text = "启用左上角缩放按钮",
        callback = function(cfg, v, loading)
            if v then
                WithAllChatFrame(function(chatFrame) if(chatFrame.ResizeButton:IsVisible()) then chatFrame.resizeButton2:Show() end end)
            else
                WithAllChatFrame(function(chatFrame) chatFrame.resizeButton2:Hide() end)
            end
            togglehook(nil, "U1Chat_ChatFrameResizeOnShow", noop, not v);
        end,
    },
    {
        var = "wheel",
        default = 1,
        type = "checkbox",
        text = "启用鼠标滚轮增强功能",
        tip = "说明`启用本功能后，按住ctrl然后滚动鼠标滚轮可以一次翻一页，按住shift然后滚动则可以翻到第一行或最末行。",
        callback = function(cfg, v, loading)
            togglehook(nil, "U1Chat_ChatFrame_OnMouseWheel", noop, not v);
        end,
    },
    {
        var = "editontop",
        default = false,
        type = "checkbox",
        text = "输入框位于窗口顶部",
        callback = function(cfg, v, loading)
            if loading and not v then return end
            U1_Chat_UpdateEditBoxPosition()
        end,
        {
            var = "offset",
            default = 0,
            type= "spin",
            range = {-100, 100, 10},
            text = "位置偏移量",
            tip = "说明`向上为正，向下为负数，默认0是在聊天标签上沿。",
            callback = function(cfg, v, loading)
                if not loading then U1CfgCallBack(cfg._parent, nil, loading); end
            end,
        }
    },
    {
        var = "format2",
        default = TIMESTAMP_FORMAT_HHMMSS_24HR,
        type = "drop",
        text = "聊天时间戳格式",
        tip = "说明`修改系统设置，美化颜色，并且可以点击时间戳复制这一行聊天文本。",
        options = tsOptions,
        confirm = "需要重载页面才能生效，是否确定",
        reload = true,
        callback = function(cfg, v, loading)
            --初始兼容
            local old = U1DB.configs["163ui_chat/format"]
            if GetCVar("showTimestamps") == "none" and old and old ~= "" then
                if old == "%M:%S" then old = TIMESTAMP_FORMAT_HHMMSS_24HR end
                U1DB.configs["163ui_chat/format"] = nil
                SetCVar("showTimestamps", old)
                CHAT_TIMESTAMP_FORMAT = old -- maybe taint, only set once.
            end
            --如果v为""，则加载我们的配置。如果v为格式值，则以cvar为准，手工修改时重载界面
            if v ~= nil and v ~= "" then
                if loading then
                    U1SaveDBValue(cfg, GetCVar("showTimestamps"))
                    U1Chat_TimeStampFormat = GetCVar("showTimestamps")
                else
                    SetCVar("showTimestamps", v);
                    ReloadUI()
                end
            else
                U1Chat_TimeStampFormat = nil
            end
        end,
    },
    {
        var = "maxLines",
        default = nil,
        type = "spin",
        range = {0, 5000, 500,},
        text = "设置聊天框的记录行数",
        cols = 4,
        callback = function(cfg, v, loading)
            U1Chat_SetMaxLines(not loading)
        end,
    },
    {
        type="button",
        id="clean",
        text="清除当前窗口",
        tip="温馨提示`请先点一下要清除窗口的标签，然后再点击此按钮",
        callback = function(cfg, v, loading)
            if SELECTED_CHAT_FRAME then
                StaticPopup_Show("163UI_CHAT_CLEAR", _G[SELECTED_CHAT_FRAME:GetName().."Tab"]:GetText());
            else
                U1Message("请先点击标签选择一个聊天框");
            end
        end,
    },
    {
        var="customtab",
        default = 1,
        text="启用TAB智能切换对话模式",
        tip="说明`按TAB键可以在说/公会/小队/团队/战场等对话模式下切换，小提示：按住SHIFT再按TAB可以向前翻。",
        callback = function(cfg, v, loading)
            togglehook(nil, "ChatEdit_CustomTabPressed_Inner", noop, not v);
        end,
        {
            var="tabchannel",
            text="是否在通用频道之间切换",
            tip="说明`循环时包含'综合','交易'等通用频道。",
        },
    },
    {
        var = 'chatColorNamesByClass',
        default = false,
        text = "聊天框名字使用职业颜色",
        tip = '说明`选中后将自动启用所有频道和玩家信息的[使用职业颜色]选项, 关闭时不会自动禁用这些选项',
        callback = function(cfg, v, loading)
            U1_Chat_EnableChatColorNamesByClassGroup(v)
        end,
    },
});
