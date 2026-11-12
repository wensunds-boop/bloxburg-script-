local sg = Instance.new("ScreenGui")
sg.Name = "Venice"
sg.ResetPlayerGuiOnSpawn = false
sg.Parent = game.Players.LocalPlayer.PlayerGui

local C = {bg=Color3.fromRGB(12,14,19),panel=Color3.fromRGB(20,24,31),card=Color3.fromRGB(28,33,42),track=Color3.fromRGB(44,50,62),text=Color3.fromRGB(233,237,245),dim=Color3.fromRGB(132,142,160),good=Color3.fromRGB(88,214,141),warn=Color3.fromRGB(255,186,84),bad=Color3.fromRGB(255,106,106),accent=Color3.fromRGB(94,141,255)}
local F=Enum.Font.GothamMedium; local FB=Enum.Font.GothamBold

local main=Instance.new("Frame")
main.Size=UDim2.fromOffset(440,520);main.Position=UDim2.fromOffset(80,80)
main.BackgroundColor3=C.bg;main.BorderSizePixel=0;main.Active=true;main.Draggable=true
local c1=Instance.new("UICorner");c1.CornerRadius=UDim.new(0,8);c1.Parent=main
local s1=Instance.new("UIStroke");s1.Color=C.track;s1.Thickness=1;s1.Parent=main

local tb=Instance.new("Frame")
tb.Size=UDim2.new(1,0,0,36);tb.BackgroundColor3=C.panel;tb.BorderSizePixel=0;tb.Parent=main
local c2=Instance.new("UICorner");c2.CornerRadius=UDim.new(0,8);c2.Parent=tb
local tt=Instance.new("TextLabel")
tt.Size=UDim2.new(1,-40,1,0);tt.Position=UDim2.fromOffset(12,0)
tt.BackgroundTransparency=1;tt.Text="⚡ Venice v2.3";tt.TextColor3=C.accent
tt.TextSize=14;tt.Font=FB;tt.TextXAlignment=Enum.TextXAlignment.Left;tt.Parent=tb
local cb=Instance.new("TextButton")
cb.Size=UDim2.fromOffset(28,28);cb.Position=UDim2.new(1,-32,0,4)
cb.BackgroundColor3=C.bad;cb.Text="✕";cb.TextColor3=C.text;cb.TextSize=13;cb.Font=FB
cb.BorderSizePixel=0;cb.Parent=tb
local c3=Instance.new("UICorner");c3.CornerRadius=UDim.new(0,6);c3.Parent=cb
cb.MouseButton1Click:Connect(function()sg:Destroy()end)

local tabs={"Player","Vehicle","Job","Players","Settings"}
local tB={};local tF={}
local tabF=Instance.new("Frame")
tabF.Size=UDim2.new(1,0,0,32);tabF.Position=UDim2.fromOffset(0,36)
tabF.BackgroundColor3=C.panel;tabF.BorderSizePixel=0;tabF.Parent=main
local cont=Instance.new("Frame")
cont.Size=UDim2.new(1,-12,1,-80);cont.Position=UDim2.fromOffset(6,74)
cont.BackgroundTransparency=1;cont.ClipsDescendants=true;cont.Parent=main

for i,n in ipairs(tabs) do
    local w=1/#tabs
    local b=Instance.new("TextButton")
    b.Size=UDim2.new(w,0,1,0);b.Position=UDim2.new(w*(i-1),0,0,0)
    b.BackgroundColor3=C.bg;b.Text=n;b.TextColor3=C.dim;b.TextSize=11;b.Font=F;b.BorderSizePixel=0;b.Parent=tabF
    local fr=Instance.new("ScrollingFrame")
    fr.Size=UDim2.new(1,0,1,0);fr.BackgroundTransparency=1;fr.BorderSizePixel=0
    fr.ScrollBarThickness=4;fr.AutomaticCanvasSize=Enum.AutomaticSize.Y;fr.Visible=false;fr.Parent=cont
    local ul=Instance.new("UIListLayout");ul.SortOrder=Enum.SortOrder.LayoutOrder;ul.Padding=UDim.new(0,5);ul.Parent=fr
    local up=Instance.new("UIPadding");up.PaddingTop=UDim.new(0,4);up.PaddingBottom=UDim.new(0,6);up.Parent=fr
    tB[n]=b;tF[n]=fr
    b.MouseButton1Click:Connect(function()
        for k in pairs(tF) do tF[k].Visible=false;tB[k].BackgroundColor3=C.bg;tB[k].TextColor3=C.dim end
        fr.Visible=true;b.BackgroundColor3=C.card;b.TextColor3=C.accent
    end)
end
tB["Player"].BackgroundColor3=C.card;tB["Player"].TextColor3=C.accent;tF["Player"].Visible=true

-- Player tab
local pc=Instance.new("Frame");pc.Size=UDim2.new(1,-4,0,0);pc.AutomaticSize=Enum.AutomaticSize.Y
pc.BackgroundColor3=C.card;pc.BorderSizePixel=0;pc.Parent=tF["Player"]
local c4=Instance.new("UICorner");c4.CornerRadius=UDim.new(0,8);c4.Parent=pc
local pp=Instance.new("UIPadding");pp.PaddingLeft=UDim.new(0,10);pp.PaddingRight=UDim.new(0,10);pp.PaddingTop=UDim.new(0,8);pp.PaddingBottom=UDim.new(0,8);pp.Parent=pc
local pl=Instance.new("UIListLayout");pl.SortOrder=Enum.SortOrder.LayoutOrder;pl.Padding=UDim.new(0,5);pl.Parent=pc

local pt=Instance.new("TextLabel");pt.Size=UDim2.new(1,0,0,18);pt.BackgroundTransparency=1
pt.Text="🏃 Rörelse";pt.TextColor3=C.accent;pt.TextSize=12;pt.Font=FB;pt.TextXAlignment=Enum.TextXAlignment.Left;pt.Parent=pc

local wsOn=false;local wsVal=34
local wr=Instance.new("Frame");wr.Size=UDim2.new(1,0,0,28);wr.BackgroundTransparency=1;wr.Parent=pc
local wt=Instance.new("TextLabel");wt.Size=UDim2.new(1,-50,1,0);wt.BackgroundTransparency=1
wt.Text="Walkspeed";wt.TextColor3=C.text;wt.TextSize=12;wt.Font=F;wt.TextXAlignment=Enum.TextXAlignment.Left;wt.Parent=wr
local wb=Instance.new("TextButton");wb.Size=UDim2.fromOffset(42,22);wb.Position=UDim2.new(1,-44,0,3)
wb.BackgroundColor3=C.track;wb.Text="AV";wb.TextColor3=C.text;wb.TextSize=10;wb.Font=FB;wb.BorderSizePixel=0;wb.Parent=wr
local c5=Instance.new("UICorner");c5.CornerRadius=UDim.new(0,6);c5.Parent=wb
wb.MouseButton1Click:Connect(function()wsOn=not wsOn;wb.BackgroundColor3=wsOn and C.good or C.track;wb.Text=wsOn and "PÅ" or "AV"end)

local jr=Instance.new("Frame");jr.Size=UDim2.new(1,0,0,28);jr.BackgroundTransparency=1;jr.Parent=pc
local jt=Instance.new("TextLabel");jt.Size=UDim2.new(1,-50,1,0);jt.BackgroundTransparency=1
jt.Text="Jump";jt.TextColor3=C.text;jt.TextSize=12;jt.Font=F;jt.TextXAlignment=Enum.TextXAlignment.Left;jt.Parent=jr
local jb=Instance.new("TextButton");jb.Size=UDim2.fromOffset(42,22);jb.Position=UDim2.new(1,-44,0,3)
jb.BackgroundColor3=C.track;jb.Text="AV";jb.TextColor3=C.text;jb.TextSize=10;jb.Font=FB;jb.BorderSizePixel=0;jb.Parent=jr
local c6=Instance.new("UICorner");c6.CornerRadius=UDim.new(0,6);c6.Parent=jb
local jpOn=false;local jpVal=50
jb.MouseButton1Click:Connect(function()jpOn=not jpOn;jb.BackgroundColor3=jpOn and C.good or C.track;jb.Text=jpOn and "PÅ" or "AV"end)

local st=Instance.new("TextLabel");st.Size=UDim2.new(1,0,0,16);st.BackgroundTransparency=1
st.Text="WS: -- | JP: --";st.TextColor3=C.dim;st.TextSize=11;st.Font=F;st.TextXAlignment=Enum.TextXAlignment.Left;st.Parent=pc

local pl2=Instance.new("Frame");pl2.Size=UDim2.new(1,-4,0,0);pl2.AutomaticSize=Enum.AutomaticSize.Y
pl2.BackgroundColor3=C.card;pl2.BorderSizePixel=0;pl2.Parent=tF["Player"]
local c7=Instance.new("UICorner");c7.CornerRadius=UDim.new(0,8);c7.Parent=pl2
local pp2=Instance.new("UIPadding");pp2.PaddingLeft=UDim.new(0,10);pp2.PaddingRight=UDim.new(0,10);pp2.PaddingTop=UDim.new(0,8);pp2.PaddingBottom=UDim.new(0,8);pp2.Parent=pl2
local pl3=Instance.new("UIListLayout");pl3.SortOrder=Enum.SortOrder.LayoutOrder;pl3.Padding=UDim.new(0,5);pl3.Parent=pl2
local pt2=Instance.new("TextLabel");pt2.Size=UDim2.new(1,0,0,18);pt2.BackgroundTransparency=1
pt2.Text="🚗 Fordon";pt2.TextColor3=C.accent;pt2.TextSize=12;pt2.Font=FB;pt2.TextXAlignment=Enum.TextXAlignment.Left;pt2.Parent=pl2
local vr=Instance.new("Frame");vr.Size=UDim2.new(1,0,0,28);vr.BackgroundTransparency=1;vr.Parent=pl2
local vt=Instance.new("TextLabel");vt.Size=UDim2.new(1,-50,1,0);vt.BackgroundTransparency=1
vt.Text="Fordonshack";vt.TextColor3=C.text;vt.TextSize=12;vt.Font=F;vt.TextXAlignment=Enum.TextXAlignment.Left;vt.Parent=vr
local vb=Instance.new("TextButton");vb.Size=UDim2.fromOffset(42,22);vb.Position=UDim2.new(1,-44,0,3)
vb.BackgroundColor3=C.track;vb.Text="AV";vb.TextColor3=C.text;vb.TextSize=10;vb.Font=FB;vb.BorderSizePixel=0;vb.Parent=vr
local c8=Instance.new("UICorner");c8.CornerRadius=UDim.new(0,6);c8.Parent=vb
local vOn=false;local vMax=130
vb.MouseButton1Click:Connect(function()vOn=not vOn;vb.BackgroundColor3=vOn and C.good or C.track;vb.Text=vOn and "PÅ" or "AV"end)
local vs=Instance.new("TextLabel");vs.Size=UDim2.new(1,0,0,16);vs.BackgroundTransparency=1
vs.Text="Inget fordon";vs.TextColor3=C.dim;vs.TextSize=11;vs.Font=F;vs.TextXAlignment=Enum.TextXAlignment.Left;vs.Parent=pl2

-- Job tab
local jc=Instance.new("Frame");jc.Size=UDim2.new(1,-4,0,0);jc.AutomaticSize=Enum.AutomaticSize.Y
jc.BackgroundColor3=C.card;jc.BorderSizePixel=0;jc.Parent=tF["Job"]
local c9=Instance.new("UICorner");c9.CornerRadius=UDim.new(0,8);c9.Parent=jc
local jp=Instance.new("UIPadding");jp.PaddingLeft=UDim.new(0,10);jp.PaddingRight=UDim.new(0,10);jp.PaddingTop=UDim.new(0,8);jp.PaddingBottom=UDim.new(0,8);jp.Parent=jc
local jl=Instance.new("UIListLayout");jl.SortOrder=Enum.SortOrder.LayoutOrder;jl.Padding=UDim.new(0,5);jl.Parent=jc
local jt2=Instance.new("TextLabel");jt2.Size=UDim2.new(1,0,0,18);jt2.BackgroundTransparency=1
jt2.Text="🍕 Pizza Farm";jt2.TextColor3=C.accent;jt2.TextSize=12;jt2.Font=FB;jt2.TextXAlignment=Enum.TextXAlignment.Left;jt2.Parent=jc
local jr2=Instance.new("Frame");jr2.Size=UDim2.new(1,0,0,28);jr2.BackgroundTransparency=1;jr2.Parent=jc
local jt3=Instance.new("TextLabel");jt3.Size=UDim2.new(1,-50,1,0);jt3.BackgroundTransparency=1
jt3.Text="Aktivera";jt3.TextColor3=C.text;jt3.TextSize=12;jt3.Font=F;jt3.TextXAlignment=Enum.TextXAlignment.Left;jt3.Parent=jr2
local jb2=Instance.new("TextButton");jb2.Size=UDim2.fromOffset(42,22);jb2.Position=UDim2.new(1,-44,0,3)
jb2.BackgroundColor3=C.track;jb2.Text="AV";jb2.TextColor3=C.text;jb2.TextSize=10;jb2.Font=FB;jb2.BorderSizePixel=0;jb2.Parent=jr2
local c10=Instance.new("UICorner");c10.CornerRadius=UDim.new(0,6);c10.Parent=jb2
local jobOn=false
jb2.MouseButton1Click:Connect(function()jobOn=not jobOn;jb2.BackgroundColor3=jobOn and C.good or C.track;jb2.Text=jobOn and "PÅ" or "AV"end)
local scanB=Instance.new("TextButton")
scanB.Size=UDim2.new(1,0,0,30);scanB.BackgroundColor3=C.warn;scanB.Text="🔍 FORCE SCAN"
scanB.TextColor3=C.text;scanB.TextSize=12;scanB.Font=FB;scanB.BorderSizePixel=0;scanB.Parent=jc
local c11=Instance.new("UICorner");c11.CornerRadius=UDim.new(0,6);c11.Parent=scanB
local jobStats=Instance.new("TextLabel");jobStats.Size=UDim2.new(1,0,0,16);jobStats.BackgroundTransparency=1
jobStats.Text="A:0 P:0 C:0 F:0";jobStats.TextColor3=C.dim;jobStats.TextSize=11;jobStats.Font=F;jobStats.TextXAlignment=Enum.TextXAlignment.Left;jobStats.Parent=jc
local jobDbg=Instance.new("TextLabel");jobDbg.Size=UDim2.new(1,0,0,16);jobDbg.BackgroundTransparency=1
jobDbg.Text="Tryck FORCE SCAN";jobDbg.TextColor3=C.dim;jobDbg.TextSize=11;jobDbg.Font=F;jobDbg.TextXAlignment=Enum.TextXAlignment.Left;jobDbg.Parent=jc

-- Players tab
local ppc=Instance.new("Frame");ppc.Size=UDim2.new(1,-4,0,0);ppc.AutomaticSize=Enum.AutomaticSize.Y
ppc.BackgroundColor3=C.card;ppc.BorderSizePixel=0;ppc.Parent=tF["Players"]
local c12=Instance.new("UICorner");c12.CornerRadius=UDim.new(0,8);c12.Parent=ppc
local pp3=Instance.new("UIPadding");pp3.PaddingLeft=UDim.new(0,10);pp3.PaddingRight=UDim.new(0,10);pp3.PaddingTop=UDim.new(0,8);pp3.PaddingBottom=UDim.new(0,8);pp3.Parent=ppc
local pl4=Instance.new("UIListLayout");pl4.SortOrder=Enum.SortOrder.LayoutOrder;pl4.Padding=UDim.new(0,5);pl4.Parent=ppc
local pt3=Instance.new("TextLabel");pt3.Size=UDim2.new(1,0,0,18);pt3.BackgroundTransparency=1
pt3.Text="👥 Spelare";pt3.TextColor3=C.accent;pt3.TextSize=12;pt3.Font=FB;pt3.TextXAlignment=Enum.TextXAlignment.Left;pt3.Parent=ppc
local pList=Instance.new("TextLabel");pList.Size=UDim2.new(1,0,0,100);pList.BackgroundTransparency=1
pList.Text="Laddar...";pList.TextColor3=C.text;pList.TextSize=11;pList.Font=F;pList.TextXAlignment=Enum.TextXAlignment.Left;pList.TextWrapped=true;pList.Parent=ppc

-- Settings tab
local sc=Instance.new("Frame");sc.Size=UDim2.new(1,-4,0,0);sc.AutomaticSize=Enum.AutomaticSize.Y
sc.BackgroundColor3=C.card;sc.BorderSizePixel=0;sc.Parent=tF["Settings"]
local c13=Instance.new("UICorner");c13.CornerRadius=UDim.new(0,8);c13.Parent=sc
local sp=Instance.new("UIPadding");sp.PaddingLeft=UDim.new(0,10);sp.PaddingRight=UDim.new(0,10);sp.PaddingTop=UDim.new(0,8);sp.PaddingBottom=UDim.new(0,8);sp.Parent=sc
local sl=Instance.new("UIListLayout");sl.SortOrder=Enum.SortOrder.LayoutOrder;sl.Padding=UDim.new(0,5);sl.Parent=sc
local st2=Instance.new("TextLabel");st2.Size=UDim2.new(1,0,0,18);st2.BackgroundTransparency=1
st2.Text="ℹ️ Info";st2.TextColor3=C.accent;st2.TextSize=12;st2.Font=FB;st2.TextXAlignment=Enum.TextXAlignment.Left;st2.Parent=sc
local fp=nil;pcall(function()if getgenv and getgenv().fireproximityprompt then fp=getgenv().fireproximityprompt end end)
local fc=nil;pcall(function()if getgenv and getgenv().fireclickdetector then fc=getgenv().fireclickdetector end end)
local info1=Instance.new("TextLabel");info1.Size=UDim2.new(1,0,0,16);info1.BackgroundTransparency=1
info1.Text="fireproximityprompt: "..(fp and "✓" or "✗");info1.TextColor3=fp and C.good or C.bad;info1.TextSize=11;info1.Font=F;info1.TextXAlignment=Enum.TextXAlignment.Left;info1.Parent=sc
local info2=Instance.new("TextLabel");info2.Size=UDim2.new(1,0,0,16);info2.BackgroundTransparency=1
info2.Text="fireclickdetector: "..(fc and "✓" or "✗");info2.TextColor3=fc and C.good or C.bad;info2.TextSize=11;info2.Font=F;info2.TextXAlignment=Enum.TextXAlignment.Left;info2.Parent=sc

-- Keybind
game:GetService("UserInputService").InputBegan:Connect(function(i,g)
    if g then return end
    if i.KeyCode==Enum.KeyCode.K then main.Visible=not main.Visible end
end)

-- Loops
spawn(function()
    while sg.Parent do
        wait(0.1)
        pcall(function()
            local ch=game.Players.LocalPlayer.Character;if not ch then return end
            local h=ch:FindFirstChildOfClass("Humanoid");if not h then return end
            if wsOn then h.WalkSpeed=wsVal end
            if jpOn then h.JumpPower=jpVal;h.UseJumpPower=true end
            st.Text="WS: "..math.floor(h.WalkSpeed).." | JP: "..math.floor(h.JumpPower)
            st.TextColor3=wsOn and C.good or C.dim
            local seat=h.SeatPart
            if vOn and seat then
                pcall(function()
                    local vs=seat:IsA("VehicleSeat") and seat or seat:FindFirstAncestorWhichIsA("VehicleSeat")
                    if vs then vs.MaxSpeed=vMax;vs.Text="Fordon: "..(vs.Parent and vs.Parent.Name or "?").." | "..vMax;vs.TextColor3=C.good end
                end)
            else
                vs.Text=seat and "Sitter i fordon" or "Inget fordon"
                vs.TextColor3=C.dim
            end
        end)
    end
end)

spawn(function()
    while sg.Parent do
        wait(3)
        pcall(function()
            local l={}
            for _,p in ipairs(game.Players:GetPlayers()) do l[#l+1]=(p==game.Players.LocalPlayer and "⭐ " or "  ")..p.Name end
            pList.Text=table.concat(l,"\n")
        end)
    end
end)

-- Pizza farm loop (manuell scan)
local pCache={};local cCache={};local cooldowns={}
scanB.MouseButton1Click:Connect(function()
    pCache={};cCache={}
    pcall(function()
        local desc=workspace:GetDescendants()
        for i=1,#desc do
            local d=desc[i]
            if d:IsA("ProximityPrompt") then pCache[#pCache+1]=d
            elseif d:IsA("ClickDetector") then cCache[#cCache+1]=d end
            if i%200==0 then wait(0.05) end
        end
    end)
    jobDbg.Text="Cache: "..#pCache.."p / "..#cCache.."c"
    jobDbg.TextColor3=C.good
end)

spawn(function()
    wait(5)
    while sg.Parent do
        wait(0.15)
        pcall(function()
            if not jobOn or #pCache==0 then return end
            local ch=game.Players.LocalPlayer.Character;if not ch then return end
            local root=ch:FindFirstChild("HumanoidRootPart");if not root then return end
            local pos=root.Position
            local fired=0;local sa=0;local sp=0;local sf=0
            for i=1,#pCache do
                if fired>=6 then break end
                local p=pCache[i]
                if not p or not p.Parent then continue end
                local part=p.Parent
                if not part:IsA("BasePart") then pcall(function()part=part:FindFirstChildWhichIsA("BasePart")end) end
                if not part or not part:IsA("BasePart") then continue end
                if (part.Position-pos).Magnitude>15 then continue end
                local now=tick();local key=tostring(p)
                if cooldowns[key] and (now-cooldowns[key])<0.6 then continue end
                local ok=false
                if fp then ok=pcall(fp,p) end
                if not ok then ok=pcall(function()local o=p.HoldDuration;p.HoldDuration=0;wait(0.05);p.HoldDuration=o end) end
                if ok then fired=fired+1;sa=sa+1;sp=sp+1;cooldowns[key]=now
                else sf=sf+1 end
            end
            if sa>0 or sf>0 then
                jobStats.Text=string.format("A:%d P:%d C:%d F:%d",sa,sp,0,sf)
            end
        end)
    end
end)

print("[Venice] v2.3 LADDAD")
game:GetService("StarterGui"):SetCore("SendNotification",{Title="Venice",Text="Laddad! [K]",Duration=4})
