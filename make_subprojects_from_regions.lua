-- @description Create subprojects from REAPER regions
-- @version 1.0.0
-- @author dylan-robins
-- @changelog
--   v1.0.0 - Initial release
--     - Based on original script by Meelis Pihlap (https://github.com/MPihlap/Reaper-Regions-To-Projects)
--     - Create subprojects from selected or all regions
--     - Async processing with progress bar
--     - Choice to delete or mute overlapping items
--     - Subproject Bus track automatically created
-- @requires Reaper 6.82
-- @about
--   Automates the process of creating subprojects from regions.
--   For each region, creates a new project file and inserts it as
--   an item on a "Subproject Bus" track, with the original content
--   either deleted or muted based on user preference.

-------------------------------------------------
-- CONFIG
-------------------------------------------------
local BUS_NAME = "Subproject Bus"

-------------------------------------------------
-- ITEM HANDLING MODE
-------------------------------------------------
local MODE_DIALOG = reaper.ShowMessageBox(
    "What to do with original items in these regions?\n\n"..
    "YES = Replace (delete original items)\n"..
    "NO  = Preserve (mute original items)\n"..
    "CANCEL = Abort",
    "Regions to Subprojects", 3)

if MODE_DIALOG == 2 then return end
local DELETE_MODE = (MODE_DIALOG == 6)

-------------------------------------------------
-- UTIL
-------------------------------------------------
local function log(msg)
    reaper.ShowConsoleMsg(msg.."\n")
end

local function get_project_info()
    local _, path = reaper.EnumProjects(-1,"")
    local dir = path:match("(.*/)")
    local name = path:match("([^/\\]+)%.rpp$")
    return dir, name or "Project"
end

-------------------------------------------------
-- REGION SELECTION
-------------------------------------------------
local function get_selected_regions()
    local regions = {}
    local _, num_markers, num_regions = reaper.CountProjectMarkers(0)
    local total = num_markers + num_regions

    for i=0,total-1 do
        local _, isrgn, pos, rgnend, name, idx =
            reaper.EnumProjectMarkers(i)
        if isrgn then
            table.insert(regions,{
                idx=idx,
                name=(name~="" and name or "Region"),
                start=pos,
                ending=rgnend
            })
        end
    end
    return regions
end

local function get_all_regions()
    local regions = {}
    local _, num_markers, num_regions = reaper.CountProjectMarkers(0)
    local total = num_markers + num_regions

    for i=0,total-1 do
        local _, isrgn, pos, rgnend, name, idx =
            reaper.EnumProjectMarkers(i)
        if isrgn then
            table.insert(regions,{
                idx=idx,
                name=(name~="" and name or "Region"),
                start=pos,
                ending=rgnend
            })
        end
    end
    return regions
end

-------------------------------------------------
-- BUS TRACK
-------------------------------------------------
local function ensure_bus_track()
    local tracks=reaper.CountTracks(0)
    for i=0,tracks-1 do
        local tr=reaper.GetTrack(0,i)
        local _,name =
            reaper.GetSetMediaTrackInfo_String(tr,"P_NAME","",false)
        if name==BUS_NAME then return tr end
    end

    reaper.InsertTrackAtIndex(tracks,true)
    local bus=reaper.GetTrack(0,tracks)
    reaper.GetSetMediaTrackInfo_String(bus,"P_NAME",BUS_NAME,true)
    return bus
end

-------------------------------------------------
-- DELETE / MUTE ITEMS (MASTER PROJECT ONLY)
-------------------------------------------------
local function handle_overlapping_items(bus,s,e)
    local tracks=reaper.CountTracks(0)
    for t=0,tracks-1 do
        local tr=reaper.GetTrack(0,t)
        if tr~=bus then
            for i=reaper.CountTrackMediaItems(tr)-1,0,-1 do
                local item = reaper.GetTrackMediaItem(tr,i)
                local pos = reaper.GetMediaItemInfo_Value(item,"D_POSITION")
                local len = reaper.GetMediaItemInfo_Value(item,"D_LENGTH")
                local fin = pos + len

                if not(fin<=s or pos>=e) then
                    if DELETE_MODE then
                        reaper.DeleteTrackMediaItem(tr,item)
                    else
                        reaper.SetMediaItemInfo_Value(item,"B_MUTE",1)
                    end
                end
            end
        end
    end
end

-------------------------------------------------
-- MAIN PROCESS
-------------------------------------------------
local dir, project_name = get_project_info()
local regions = get_selected_regions()

if #regions==0 then
    local ret=reaper.ShowMessageBox(
        "No selected regions.\nProcess ALL regions?",
        "Regions → Subprojects",4)
    if ret~=6 then return end
    regions=get_all_regions()
end

if #regions==0 then
    reaper.ShowMessageBox("No regions found.","Info",0)
    return
end

local bus = ensure_bus_track()
local original_proj = select(2,reaper.EnumProjects(-1,""))
local i = 1
local total = #regions

reaper.Undo_BeginBlock()
reaper.PreventUIRefresh(1)

local function process_next()
    if i>total then
        reaper.PreventUIRefresh(-1)
        reaper.UpdateArrange()
        reaper.Undo_EndBlock("Create subprojects from regions (PRO SAFE MASTER)",-1)
        reaper.ClearConsole()
        reaper.ShowMessageBox("Done! "..total.." subprojects created.","Finished",0)
        return
    end

    local r = regions[i]
    local filename = string.format("%s%d_%s_%s.rpp", dir, r.idx, r.name, project_name)

    -- progress bar
    local pct=i/total
    reaper.ShowConsoleMsg("")
    reaper.ShowConsoleMsg(string.format("Creating subprojects...\n[%d/%d] %.0f%%", i,total,pct*100))

    -- Save new subproject copy (always save a fresh copy)
    reaper.Main_SaveProjectEx(0,filename,0)
    reaper.Main_OnCommand(40859,0)
    reaper.Main_openProject("noprompt:"..filename)
    
    -- Bypass master FX chain to avoid double processing
    local master = reaper.GetMasterTrack(0)
    for fx_idx = 0, reaper.TrackFX_GetCount(master) - 1 do
        reaper.TrackFX_SetOffline(master, fx_idx, true)
    end
    
    reaper.GetSet_LoopTimeRange(true,false,r.start,r.ending,false)
    reaper.Main_OnCommand(40049,0)
    reaper.Main_SaveProject(0,false)
    reaper.Main_OnCommand(40860,0)  -- Close current tab (subproject)
    
    -- Now fully back in master project
    reaper.SelectProjectInstance(original_proj)
    reaper.Main_OnCommand(40297,0)
    reaper.SetOnlyTrackSelected(bus)
    reaper.SetEditCurPos(r.start,false,false)
    reaper.InsertMedia(filename,0)

    -- Delete the original subproject file (keep only the -imported version)
    os.remove(filename)

    -- Delete or mute items overlapping this region
    handle_overlapping_items(bus,r.start,r.ending)

    i=i+1
    reaper.defer(process_next)
end

process_next()