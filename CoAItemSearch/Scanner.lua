-- CoA Item Search Database Harvester v1.0.1; WoW 3.3.5a
-- Queries the client cache; this cannot enumerate guaranteed server-side items.
local addon=CreateFrame('Frame')
local db, running, accumulator, uiClock = nil,false,0,0
local speeds={12,50,100,200}
local pendingOrder, pendingHead, pendingTail = {},1,0
local retryOrder, retryHead, retryTail = {},1,0
local MAX_PENDING=350
local function say(s) DEFAULT_CHAT_FRAME:AddMessage('|cff33bbffCoA Harvester:|r '..s) end
local function ensure()
 CoAItemSearchHarvest=CoAItemSearchHarvest or {}
 db=CoAItemSearchHarvest
 db.items=db.items or {}
 db.cursor=tonumber(db.cursor) or 1
 db.maxID=tonumber(db.maxID) or 250000
 db.checked=tonumber(db.checked) or 0
 db.found=tonumber(db.found) or 0
 db.speed=tonumber(db.speed) or 50
 db.speedIndex=tonumber(db.speedIndex) or 2
 db.retryCount=tonumber(db.retryCount) or 0
 db.pending=db.pending or {}
 -- Old v1.0.0 stored every unresolved ID as true. Those are not reliable
 -- retry jobs and would make a huge unbounded saved-variable table.
 for id in pairs(db.pending) do db.pending[id]=nil end
 local n=0 for _ in pairs(db.items) do n=n+1 end
 db.found=n
end
local function record(id)
 if not db then return false end
 local name,link,quality,ilvl,required,itemType,subType,stack,equip,texture,sell=GetItemInfo(id)
 if not name then return false end
 if not db.items[id] then db.found=db.found+1 end
 db.items[id]={name,quality or -1,ilvl or 0,required or 0,itemType or '',subType or '',stack or 0,equip or '',sell or 0,texture or ''}
 db.pending[id]=nil
 return true
end
local function queue(id)
 if db.pending[id] or db.items[id] then return end
 if pendingTail-pendingHead+1>=MAX_PENDING then
  local old=pendingOrder[pendingHead]; pendingOrder[pendingHead]=nil; pendingHead=pendingHead+1
  if old and db.pending[old] then db.pending[old]=nil; db.retryCount=db.retryCount+1 end
 end
 pendingTail=pendingTail+1; pendingOrder[pendingTail]=id; db.pending[id]=1
end
local function query(id)
 if record(id) then return true end
 -- Item links can trigger a cache lookup on supported clients.
 GetItemInfo('item:'..id)
 if record(id) then return true end
 queue(id)
 return false
end
addon:RegisterEvent('ADDON_LOADED')
addon:RegisterEvent('GET_ITEM_INFO_RECEIVED')
addon:SetScript('OnEvent',function(self,event,a,b)
 if event=='ADDON_LOADED' and a=='CoAItemSearch' then ensure()
 elseif event=='GET_ITEM_INFO_RECEIVED' and db and tonumber(a) and b then record(tonumber(a)) end
end)
local panel=CreateFrame('Frame','CoAItemSearchHarvestFrame',UIParent)
panel:SetSize(430,305); panel:SetPoint('CENTER',UIParent,'CENTER',230,0)
panel:SetBackdrop({bgFile='Interface\\DialogFrame\\UI-DialogBox-Background',edgeFile='Interface\\DialogFrame\\UI-DialogBox-Border',tile=true,tileSize=32,edgeSize=32,insets={left=10,right=10,top=10,bottom=10}})
panel:SetMovable(true);panel:EnableMouse(true);panel:RegisterForDrag('LeftButton')
panel:SetScript('OnDragStart',panel.StartMoving);panel:SetScript('OnDragStop',panel.StopMovingOrSizing)
panel:Hide(); tinsert(UISpecialFrames,'CoAItemSearchHarvestFrame')
local heading=panel:CreateFontString(nil,'OVERLAY','GameFontNormalLarge')
heading:SetPoint('TOP',0,-19);heading:SetText('CoA Database Harvester v1.0.1')
local status=panel:CreateFontString(nil,'OVERLAY','GameFontHighlight')
status:SetPoint('TOPLEFT',22,-54);status:SetWidth(385);status:SetJustifyH('LEFT')
local help=panel:CreateFontString(nil,'OVERLAY','GameFontHighlightSmall')
help:SetPoint('TOPLEFT',22,-109);help:SetWidth(385);help:SetJustifyH('LEFT')
help:SetText('AFK scan uses client item lookups; not every server item is exposed. /reload or logout writes discoveries to disk.')
local function button(label,x,y,w,fn)
 local b=CreateFrame('Button',nil,panel,'UIPanelButtonTemplate')
 b:SetSize(w,25);b:SetPoint('TOPLEFT',x,y);b:SetText(label);b:SetScript('OnClick',fn);return b
end
local function update()
 if not db then return end
 status:SetText(string.format('%s | IDs checked: %d | Items found: %d\nNext ID: %d / %d | Speed: %d IDs/sec\nUnresolved queries (bounded): %d',running and 'SCANNING' or 'PAUSED',db.checked,db.found,db.cursor,db.maxID,db.speed,math.max(0,pendingTail-pendingHead+1)))
end
button('Start / Resume',20,-160,130,function() ensure();running=true;update() end)
button('Pause',158,-160,95,function() running=false;update() end)
button('New IDs',260,-160,145,function() ensure();db.cursor=db.maxID+1;db.maxID=db.maxID+50000;running=true;update() end)
button('12 / sec',20,-194,90,function() db.speed=12;db.speedIndex=1;update() end)
button('50 / sec',119,-194,90,function() db.speed=50;db.speedIndex=2;update() end)
button('100 / sec',218,-194,90,function() db.speed=100;db.speedIndex=3;update() end)
button('200 / sec',317,-194,90,function() db.speed=200;db.speedIndex=4;update() end)
button('Save checkpoint',20,-228,185,function() running=false;update();say('Paused. /reload or logout to write SavedVariables.') end)
button('Close',222,-228,183,function() panel:Hide() end)
local footer=panel:CreateFontString(nil,'OVERLAY','GameFontDisableSmall')
footer:SetPoint('BOTTOM',0,21);footer:SetText('WTF/Account/<account>/SavedVariables/CoAItemSearch.lua')
local close=CreateFrame('Button',nil,panel,'UIPanelCloseButton');close:SetPoint('TOPRIGHT',-5,-5)
addon:SetScript('OnUpdate',function(self,dt)
 if not db then return end
 uiClock=uiClock+dt
 if running then
  accumulator=math.min(accumulator+dt*db.speed,db.speed*2)
  local budget=math.min(math.floor(accumulator),30)
  accumulator=accumulator-budget
  for i=1,budget do
   if db.cursor>db.maxID then running=false;say('Scan complete. /reload or logout to save.');break end
   local id=db.cursor;db.cursor=id+1;db.checked=db.checked+1
   if not db.items[id] then query(id) end
  end
 end
 -- Retry a small number of unresolved IDs once after moving on.
 -- Do not retain an unbounded queue or repeat failed queries forever.
 if running and uiClock>=0.5 then
  local tries=0
  while tries<5 and pendingHead<=pendingTail do
   local id=pendingOrder[pendingHead];pendingOrder[pendingHead]=nil;pendingHead=pendingHead+1
   if id and db.pending[id] then
    if not record(id) then GetItemInfo('item:'..id);record(id) end
    db.pending[id]=nil
   end
   tries=tries+1
  end
 end
 if uiClock>=0.5 then uiClock=0; if panel:IsShown() then update() end end
end)
SLASH_COAHARVEST1='/harvestitems'
SlashCmdList.COAHARVEST=function() ensure();if panel:IsShown() then panel:Hide() else panel:Show();update() end end
local launcher=CreateFrame('Button',nil,UIParent,'UIPanelButtonTemplate')
launcher:SetSize(110,24);launcher:SetPoint('CENTER',UIParent,'CENTER',0,-310)
launcher:SetText('Item Harvester');launcher:SetMovable(true);launcher:EnableMouse(true)
launcher:RegisterForDrag('LeftButton');launcher:SetScript('OnDragStart',launcher.StartMoving);launcher:SetScript('OnDragStop',launcher.StopMovingOrSizing)
launcher:SetScript('OnClick',function() ensure();panel:Show();update() end)
launcher:SetScript('OnEnter',function(self) GameTooltip:SetOwner(self,'ANCHOR_TOP');GameTooltip:SetText('Open database scanner. Drag to reposition.');GameTooltip:Show() end)
launcher:SetScript('OnLeave',function() GameTooltip:Hide() end)
