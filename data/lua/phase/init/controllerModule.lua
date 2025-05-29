local tool = require './module/toolModule'
local envM = require './module/envModule'
local blockM = require './module/waf/blockModule'

------------------
--set prepareInfo
------------------
envM.get()

------------------
--set local block ip
------------------
blockM.load_block_ip()