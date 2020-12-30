--redefine keybindings here if needed; multiple bindings are possible
keybinds = {
            activate = {'\\', 'MOUSE_BTN2'},
            plsup = {'UP', 'MOUSE_BTN3'},
            plsdown = {'DOWN', 'MOUSE_BTN4'},
            plsenter = {'ENTER', 'MOUSE_BTN0'}
        }
--hide playlist after specified number of seconds
osd_time=10
--show only specified number of playlist entries
window=7
--fade video when showing playlist
fade=false
--if fade=true; -100 — black, 0 — normal
plsbrightness=-70
--favorites get promotion to the top of the pls
favorites = {}
-- END OF CONFIGURABLE VARIABLES

local timer
--local plscount
local pattern=""
local is_active
local is_playlist_loaded

-- UTF-8 lower/upper conversion
local utf8_lc_uc = {
  ["a"] = "A",
  ["b"] = "B",
  ["c"] = "C",
  ["d"] = "D",
  ["e"] = "E",
  ["f"] = "F",
  ["g"] = "G",
  ["h"] = "H",
  ["i"] = "I",
  ["j"] = "J",
  ["k"] = "K",
  ["l"] = "L",
  ["m"] = "M",
  ["n"] = "N",
  ["o"] = "O",
  ["p"] = "P",
  ["q"] = "Q",
  ["r"] = "R",
  ["s"] = "S",
  ["t"] = "T",
  ["u"] = "U",
  ["v"] = "V",
  ["w"] = "W",
  ["x"] = "X",
  ["y"] = "Y",
  ["z"] = "Z",
  ["а"] = "А",
  ["б"] = "Б",
  ["в"] = "В",
  ["г"] = "Г",
  ["д"] = "Д",
  ["е"] = "Е",
  ["ж"] = "Ж",
  ["з"] = "З",
  ["и"] = "И",
  ["й"] = "Й",
  ["к"] = "К",
  ["л"] = "Л",
  ["м"] = "М",
  ["н"] = "Н",
  ["о"] = "О",
  ["п"] = "П",
  ["р"] = "Р",
  ["с"] = "С",
  ["т"] = "Т",
  ["у"] = "У",
  ["ф"] = "Ф",
  ["х"] = "Х",
  ["ц"] = "Ц",
  ["ч"] = "Ч",
  ["ш"] = "Ш",
  ["щ"] = "Щ",
  ["ъ"] = "Ъ",
  ["ы"] = "Ы",
  ["ь"] = "Ь",
  ["э"] = "Э",
  ["ю"] = "Ю",
  ["я"] = "Я",
  ["ё"] = "Ё"
}

local utf8_uc_lc = {
  ["A"] = "a",
  ["B"] = "b",
  ["C"] = "c",
  ["D"] = "d",
  ["E"] = "e",
  ["F"] = "f",
  ["G"] = "g",
  ["H"] = "h",
  ["I"] = "i",
  ["J"] = "j",
  ["K"] = "k",
  ["L"] = "l",
  ["M"] = "m",
  ["N"] = "n",
  ["O"] = "o",
  ["P"] = "p",
  ["Q"] = "q",
  ["R"] = "r",
  ["S"] = "s",
  ["T"] = "t",
  ["U"] = "u",
  ["V"] = "v",
  ["W"] = "w",
  ["X"] = "x",
  ["Y"] = "y",
  ["Z"] = "z",
  ["А"] = "а",
  ["Б"] = "б",
  ["В"] = "в",
  ["Г"] = "г",
  ["Д"] = "д",
  ["Е"] = "е",
  ["Ж"] = "ж",
  ["З"] = "з",
  ["И"] = "и",
  ["Й"] = "й",
  ["К"] = "к",
  ["Л"] = "л",
  ["М"] = "м",
  ["Н"] = "н",
  ["О"] = "о",
  ["П"] = "п",
  ["Р"] = "р",
  ["С"] = "с",
  ["Т"] = "т",
  ["У"] = "у",
  ["Ф"] = "ф",
  ["Х"] = "х",
  ["Ц"] = "ц",
  ["Ч"] = "ч",
  ["Ш"] = "ш",
  ["Щ"] = "щ",
  ["Ъ"] = "ъ",
  ["Ы"] = "ы",
  ["Ь"] = "ь",
  ["Э"] = "э",
  ["Ю"] = "ю",
  ["Я"] = "я",
  ["Ё"] = "ё"
}

--utf8 char pattern
local utf8_char="[\1-\127\192-\223][\128-\191]*"

local cyr_chars={'а','б','в','г','д','е','ё','ж','з','и','й','к','л','м','н','о','п','р','с','т','у','ф','х','ц','ч','ш','щ','ъ','ы','ь','э','ю','я'}

-- символы, которые возможно вводить для поиска
local chars={}
for i=string.byte('a'),string.byte('z') do
  table.insert(chars,i)
end
for i=string.byte('A'),string.byte('Z') do
  table.insert(chars,i)
end
for i=string.byte('0'),string.byte('9') do
  table.insert(chars,i)
end
for _,v in ipairs({',','^','$','(',')','%','.','[',']','*','+','-','?','`',"'",";"}) do
  table.insert(chars,string.byte(v))
end

local keybinder = { 
  remove = function(action)
    for i,_ in ipairs(keybinds[action]) do
      mp.remove_key_binding(action..tostring(i))
    end
  end,
  add = function(action, func, repeatable)
    for i,key in ipairs(keybinds[action]) do
      assert(type(func)=="function", "not a function")
      if repeatable then
        mp.add_forced_key_binding(key, action..tostring(i), func, "repeatable")
      else
        mp.add_forced_key_binding(key, action..tostring(i), func)
      end
    end
  end
}

local fader = {
  saved_brtns,
  on = function(self)
    if fade and not self.saved_brtns then
        self.saved_brtns = mp.get_property("brightness")
        mp.set_property("brightness", plsbrightness)
    end
  end,
  off = function(self)
    if fade and self.saved_brtns then
      mp.set_property("brightness", self.saved_brtns)
      self.saved_brtns=nil
    end
  end
}

local playlister = {
-- pls — список элементов плейлиста
  pls,
-- plsfiltered — список индексов выбранных фильтром элементов плейлиста
  plsfiltered,
  plspos,
  wndstart,
  wndend,
  cursor,

  init = function(self)
    if not self.pls then
      self.pls = mp.get_property_native("playlist")
    end
    mp.commandv("stop")
    --need to mark first entry non-current (mpv bug?)
    if self.pls[1] then
      self.pls[1].current = false
    end
    if favorites and #favorites>0 then
      self:sortfavs()
    end
    pattern = ""
    self.plsfiltered = tablekeys(self.pls)
  end,

  show = function(self)
    local i
    local newpos
    local msg
    --media-title
    --playlist t[2].title

    if not self.plsfiltered then
      return
    end
    if not self.wndstart or not self.cursor then
      self.wndstart=1
      self.cursor=0
    end
  
    msg=""
    i = self.wndstart
    local prefix
    while self.plsfiltered[i] and i<=self.wndstart+window-1 do
      if self.pls[self.plsfiltered[i]].current then
        prefix="*"
      elseif i==self.wndstart+self.cursor then
        prefix=">"
      else
        prefix="  "
      end
      msg = msg..prefix..(self.pls[self.plsfiltered[i]].title or "").."\n"
      i=i+1
    end
    if self.wndstart>1 then
      msg = "...\n"..msg
    else
      msg = " \n"..msg
    end
    if self.wndstart+window-1<#self.plsfiltered then
      msg = msg.."..."
    end
    msg="/"..pattern.."\n"..msg
    mp.osd_message(msg, osd_time)
  end,

  sortfavs = function(self)
    --favorites bubbles to the top
    local favs={}
    local nonfavs={}
    for _,v in ipairs(self.pls) do
      if in_array(favorites,v.title) then
        favs[#favs+1] = v
      else
        nonfavs[#nonfavs+1] = v
      end
    end
    for i=1,#nonfavs do
      favs[#favs+1] = nonfavs[i]
    end
    self.pls = favs
  end,

  filter = function(self)
    self.plsfiltered={}
    for i,v in ipairs(self.pls) do
      if string.match(mylower(v.title),'.*'..prepat(pattern)..'.*') then
        table.insert(self.plsfiltered,i)
      end
    end
    self.wndstart=1
    self.cursor=0
  end,

  down = function(self)
    if self.cursor >= #self.plsfiltered-1 then return end
    if self.cursor<window-1 then
      self.cursor=self.cursor+1
    else
      if self.wndstart<#self.plsfiltered-window+1 then
        self.wndstart=self.wndstart+1
      end
    end
    self.show(self)
  end,
  up = function(self)
    if self.cursor>0 then
      self.cursor=self.cursor-1
      self.show(self)
    else
      if self.wndstart>1 then
        self.wndstart=self.wndstart-1
        self.show(self)
      end
    end
  end,

  play = function(self)
    mp.commandv("loadfile",self.pls[self.plsfiltered[self.wndstart+self.cursor]].filename)
    if self.plspos then
      self.pls[self.plspos].current=false
    end
    self.plspos=self.plsfiltered[self.wndstart+self.cursor]
    self.pls[self.plspos].current=true
  end
}

function add_bindings()
  keybinder.add("plsup", up, true)
  keybinder.add("plsdown", down, true)
  for i,v in ipairs(chars) do
    c=string.char(v)
    mp.add_forced_key_binding(c, 'search'..v, typing(c),"repeatable")
  end
  mp.add_forced_key_binding('SPACE', 'search32', typing(' '),"repeatable")
    
--[[    mp.add_key_binding('а', 'search1000', typing('а'),"repeatable")
    mp.add_key_binding('с', 'search1001', typing('с'),"repeatable")]]

  mp.add_forced_key_binding('BS', 'searchbs', backspace,"repeatable")
  keybinder.add("plsenter", play)
  for i,v in ipairs(cyr_chars) do
    mp.add_forced_key_binding(v, 'search'..i+1000, typing(v),"repeatable")
  end
end

function remove_bindings()
  keybinder.remove('plsup')
  keybinder.remove('plsdown')
  keybinder.remove('plsenter')
  for i,v in ipairs(chars) do
    c=string.char(v)
    mp.remove_key_binding('search'..v)
  end
  mp.remove_key_binding('search32')
  mp.remove_key_binding('searchbs')
  for i,v in ipairs(cyr_chars) do
    mp.remove_key_binding('search'..i+1000)
  end
end

function activate()
  if is_active then
    shutdown()
    return
  else
    is_active=true
    fader:on()
    playlister:show()
    add_bindings()
    if not timer then
      timer=mp.add_periodic_timer(osd_time, shutdown)
      timer.oneshot=true
    else
      resumetimer()
    end
  end
end

function tablekeys(t)
  local result={}
  for i,v in ipairs(t) do
    table.insert(result,i)
  end
  return result
end

function in_array(array, value)
  for _,v in ipairs(array) do
    if v==value then
      return true
    end
  end
  return false
end

function mylower(s)
  local res,n =  string.gsub(s,utf8_char,function (c) 
                                    return utf8_uc_lc[c]
                                 end)
  return res
end

function myupper(s)
  local res,n =  string.gsub(s,utf8_char,function (c) 
                                    return utf8_lc_uc[c]
                                 end)
  return res
end

function prepat(s)
--prepare nocase and magic chars
  s = string.gsub(s, "[%^%$%(%)%%%.%[%]%*%+%-%?]",function (c)
        return '%'..c
      end)
--[[  s = string.gsub(s, utf8_char, function (c)
        return string.format("[%s%s]", utf8_uc_lc[c] or c, utf8_lc_uc[c] or c)
      end)]]
  return s
end

function resumetimer()
  timer:kill()
  timer:resume()
end

function typing(char)
  return function()
           local c=string.lower(char)
           pattern = pattern..c
           playlister:filter()
           playlister:show()
           resumetimer()
         end
end

function backspace()
  if string.len(pattern)>0 then
--    pattern = string.sub(pattern,1,-2)
-- for unicode
    pattern = string.match(pattern,"(.*)"..utf8_char.."$")
    playlister:filter()
    playlister:show()
    resumetimer()
  end
end

function play()
--  mp.commandv("playlist-move", wndstart+cursor, 1)
--  mp.commandv("playlist-clear")
--  mp.commandv("playlist-next")
  fader:off()
  playlister:play()
  playlister:show()
  resumetimer()
end

function shutdown()
  fader:off()
  remove_bindings()
  is_active=false
  mp.osd_message("", 1)
end

function down()
  fader:on()
  playlister:down()
  resumetimer()
end

function up()
  fader:on()
  playlister:up()
  resumetimer()
end

function on_start_file()
  if is_playlist_loaded then
    playlister:init()
    mp.unregister_event(on_start_file)
    activate()
  else
    is_playlist_loaded = true
  end
end

--~ function on_shutdown()
  --~ fader:off()
--~ end

if mp.get_opt("iptv") then
  mp.set_property_bool("idle", true)
  mp.set_property_bool("force-window", true)
  mp.register_event("start-file", on_start_file)
  --~ mp.register_event("end-file", on_shutdown)
  keybinder.add("activate", activate)
end

