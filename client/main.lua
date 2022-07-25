local QBCore = exports['qb-core']:GetCoreObject()
local playerJob = nil
local garbageVehicle = nil
local hasBag = false
local currentStop = 0
local deliveryBlip = nil
local isWorking = false
local amountOfBags = 0
local garbageObject = nil
local endBlip = nil
local garbageBlip = nil
local canTakeBag = true
local currentStopNum = 0
local payCoords = vector3(Config.Locations["paycheck"].coords.x, Config.Locations["paycheck"].coords.y, Config.Locations["paycheck"].coords.z)
local vehCoords = vector3(Config.Locations["vehicle"].coords.x, Config.Locations["vehicle"].coords.y, Config.Locations["vehicle"].coords.z)

-- Handlers

local function setupClient()
    garbageVehicle = nil
    hasBag = false
    currentStop = 0
    deliveryBlip = nil
    isWorking = false
    amountOfBags = 0
    garbageObject = nil
    endBlip = nil
    currentStopNum = 0
    if playerJob.name == "garbage" then
        garbageBlip = AddBlipForCoord(Config.Locations["main"].coords.x, Config.Locations["main"].coords.y, Config.Locations["main"].coords.z)
        SetBlipSprite(garbageBlip, 318)
        SetBlipDisplay(garbageBlip, 4)
        SetBlipScale(garbageBlip, 0.8)
        SetBlipAsShortRange(garbageBlip, true)
        SetBlipColour(garbageBlip, 60)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentSubstringPlayerName(Config.Locations["main"].label)
        EndTextCommandSetBlipName(garbageBlip)
    end
end

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    playerJob = QBCore.Functions.GetPlayerData().job
    setupClient()
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(JobInfo)
    playerJob = JobInfo
    if playerJob.name == "garbage" then
        if garbageBlip ~= nil then
            RemoveBlip(garbageBlip)
        end
    end
    setupClient()
end)

AddEventHandler('onResourceStop', function(resource)
    if GetCurrentResourceName() == resource then
        if garbageObject ~= nil then
            DeleteEntity(garbageObject)
            garbageObject = nil
        end
    end
end)

AddEventHandler('onResourceStart', function(resource)
    if GetCurrentResourceName() == resource then
        playerJob = QBCore.Functions.GetPlayerData().job
        setupClient()
    end
end)

-- Functions
local function LoadAnimation(dict)
    RequestAnimDict(dict)
	while not HasAnimDictLoaded(dict) do Wait(10) end
end

local function BringBackCar()
    local veh = GetVehiclePedIsIn(PlayerPedId())
    DeleteVehicle(veh)
    if endBlip ~= nil then
        RemoveBlip(endBlip)
    end
    if deliveryBlip ~= nil then
        RemoveBlip(deliveryBlip)
    end
    garbageVehicle = nil
    hasBag = false
    currentStop = 0
    deliveryBlip = nil
    isWorking = false
    amountOfBags = 0
    garbageObject = nil
    endBlip = nil
    currentStopNum = 0
end

local function SetRouteBack()
    local inleverpunt = Config.Locations["vehicle"]
    endBlip = AddBlipForCoord(inleverpunt.coords.x, inleverpunt.coords.y, inleverpunt.coords.z)
    exports['qb-target']:RemoveZone('trashcans')
    SetBlipSprite(endBlip, 1)
    SetBlipDisplay(endBlip, 2)
    SetBlipScale(endBlip, 1.0)
    SetBlipAsShortRange(endBlip, false)
    SetBlipColour(endBlip, 3)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName(Config.Locations["vehicle"].name)
    EndTextCommandSetBlipName(endBlip)
    SetBlipRoute(endBlip, true)
    SetBlipRouteColour(endBlip, 49)
end

local function AnimCheck()
    CreateThread(function()
        while true do
            local ped = PlayerPedId()
            if hasBag then
                if not IsEntityPlayingAnim(ped, 'missfbi4prepp1', '_bag_walk_garbage_man', 3) then
                    ClearPedTasksImmediately(ped)
                    LoadAnimation('missfbi4prepp1')
                    TaskPlayAnim(ped, 'missfbi4prepp1', '_bag_walk_garbage_man', 6.0, -6.0, -1, 49, 0, 0, 0, 0)
                end
            else
                break
            end
            Wait(200)
        end
    end)
end

local function TakeAnim()
    local ped = PlayerPedId()
    LoadAnimation('missfbi4prepp1')
    TaskPlayAnim(ped, 'missfbi4prepp1', '_bag_walk_garbage_man', 6.0, -6.0, -1, 49, 0, 0, 0, 0)
    garbageObject = CreateObject(`prop_cs_rub_binbag_01`, 0, 0, 0, true, true, true)
    AttachEntityToEntity(garbageObject, ped, GetPedBoneIndex(ped, 57005), 0.12, 0.0, -0.05, 220.0, 120.0, 0.0, true, true, false, true, 1, true)
    AnimCheck()
end

local function DeliverAnim()
    local ped = PlayerPedId()
    LoadAnimation('missfbi4prepp1')
    TaskPlayAnim(ped, 'missfbi4prepp1', '_bag_throw_garbage_man', 8.0, 8.0, 1100, 48, 0.0, 0, 0, 0)
    FreezeEntityPosition(ped, true)
    SetEntityHeading(ped, GetEntityHeading(garbageVehicle))
    canTakeBag = false
    SetTimeout(1250, function()
        DetachEntity(garbageObject, 1, false)
        DeleteObject(garbageObject)
        TaskPlayAnim(ped, 'missfbi4prepp1', 'exit', 8.0, 8.0, 1100, 48, 0.0, 0, 0, 0)
        FreezeEntityPosition(ped, false)
        garbageObject = nil
        canTakeBag = true
    end)
end

local function SetGarbageRoute()
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local CurrentLocation = Config.Locations["trashcan"][currentStop]
    if deliveryBlip ~= nil then
        RemoveBlip(deliveryBlip)
    end
    exports['qb-target']:AddBoxZone("trashcans", vector3(CurrentLocation.pz), CurrentLocation.length, CurrentLocation.width, {
        name = "trashcans",
        heading = CurrentLocation.heading,
        debugPoly = false,
        minZ = CurrentLocation.minZ,
        maxZ = CurrentLocation.maxZ,
        }, {
            options = {
                {
                    type = "client",
                    event = "garbage:takeBag",
                    icon = "fas fa-sign-in-alt",
                    label = "Get bag of trash",
                    job = "garbage",
                },
            },
            distance = 2.5
    })
    deliveryBlip = AddBlipForCoord(CurrentLocation.coords.x, CurrentLocation.coords.y, CurrentLocation.coords.z)
    SetBlipSprite(deliveryBlip, 1)
    SetBlipDisplay(deliveryBlip, 2)
    SetBlipScale(deliveryBlip, 1.0)
    SetBlipAsShortRange(deliveryBlip, false)
    SetBlipColour(deliveryBlip, 27)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName(Config.Locations["trashcan"][currentStop].name)
    EndTextCommandSetBlipName(deliveryBlip)
    SetBlipRoute(deliveryBlip, true)
    SetBlipRouteColour(deliveryBlip,69)

end

RegisterNetEvent('garbage:takeBag', function()
    local ped = PlayerPedId()
    if currentStop ~= 0 and deliveryBlip ~= nil then
        QBCore.Functions.Progressbar('garbage_grab', 'Grabbing Garbage Bag...', 2000, false, true, { -- Name | Label | Time | useWhileDead | canCancel
            disableMovement = true,
            disableCarMovement = true,
            disableMouse = false,
            disableCombat = true,
            }, {
                animDict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@',
                anim = 'machinic_loop_mechandplayer',
                flags = 16,
            }, {}, {}, function() -- Play When Done
                ClearPedTasks(ped)
                if not hasBag and canTakeBag then
                    hasBag = true
                    TakeAnim()
                end
            end, function() -- Play When Cancel

        end)
    else
        QBCore.Functions.Notify("Go clock in to collect trash.", 'error')
    end
end)

RegisterNetEvent('garbage:putTrashTruck', function()
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    if hasBag then
        LoadAnimation('missfbi4prepp1')
        if DoesEntityExist(garbageVehicle) then
            QBCore.Functions.Progressbar("deliverbag", "Putting bag in trashmaster ..", 1000, false, true, {
                disableMovement = true,
                disableCarMovement = true,
                disableMouse = false,
                disableCombat = true,
            }, {}, {}, {}, function() -- Done
                hasBag = false
                -- Looks if you have delivered all bags
                if (amountOfBags - 1) == 0 then
                    QBCore.Functions.TriggerCallback('garbagejob:server:NextStop', function(hasMoreStops, nextStop, newBagAmount)
                        if hasMoreStops and nextStop ~= 0 then
                            -- Here he puts your next location and you are not finished working yet.
                            currentStop = nextStop
                            currentStopNum = currentStopNum + 1
                            amountOfBags = newBagAmount
                            SetGarbageRoute()
                            QBCore.Functions.Notify("All garbage bags are done, proceed to the next location!")
                        else
                            if hasMoreStops and nextStop == currentStop then
                                QBCore.Functions.Notify("There was an issue at the depot, please return immediately!")
                                amountOfBags = 0
                            else
                                -- You are done with work here.
                                QBCore.Functions.Notify("You are done working! Go back to the depot.")
                                isWorking = false
                                RemoveBlip(deliveryBlip)
                                SetRouteBack()
                                amountOfBags = 0
                            end
                        end
                    end, currentStop, currentStopNum, pos)
                    hasBag = false
                else
                    -- You haven't delivered all bags here
                    amountOfBags = amountOfBags - 1
                    if amountOfBags > 1 then
                        QBCore.Functions.Notify("There are still "..amountOfBags.." bags left!")
                    else
                        QBCore.Functions.Notify("There is still "..amountOfBags.." bags over there!")
                    end
                    hasBag = false
                end

                DeliverAnim()
            end, function() -- Cancel
                QBCore.Functions.Notify("Canceled", "error")
            end)
        else
            QBCore.Functions.Notify("You have no truck", "error")
            -- print("You no longer have a truck, contact an admin!")
            DeliverAnim()
            hasBag = false
        end
    else
        QBCore.Functions.Notify("You don\'t have trash..", "error")
    end
end)

-- Events
RegisterNetEvent('garbagejob:client:SetWaypointHome', function()
    SetNewWaypoint(Config.Locations["main"].coords.x, Config.Locations["main"].coords.y)
end)

RegisterNetEvent('garbage:paySlip', function()
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local distance = #(pos - payCoords)
    if distance < 5.5  then
        if deliveryBlip ~= nil then
            RemoveBlip(deliveryBlip)
        end
        TriggerServerEvent('garbagejob:server:PayShift')
        exports['qb-target']:RemoveZone('trashcans')
    end
end)

RegisterNetEvent('garbage:getTruck', function()
    QBCore.Functions.TriggerCallback('garbagejob:server:NewShift', function(shouldContinue, firstStop, totalBags)
        if shouldContinue then
            local coords = Config.Locations["vehicle"].coords
            QBCore.Functions.SpawnVehicle("trash2", function(veh)
               --- TaskWarpPedIntoVehicle(ped, veh, -1) -- hopefully this fixes an issue if something is delayed they'll get crushed
                SetVehicleEngineOn(veh, true, true)
                garbageVehicle = veh
                NetworkRegisterEntityAsNetworked(garbageVehicle)
                SetVehicleNumberPlateText(veh, "GARB"..tostring(math.random(1000, 9999)))
                SetEntityHeading(veh, coords.w)
                exports['LegacyFuel']:SetFuel(veh, 100.0)
                SetEntityAsMissionEntity(veh, true, true)
                TriggerEvent("vehiclekeys:client:SetOwner", QBCore.Functions.GetPlate(veh))
                exports['qb-target']:AddTargetEntity(garbageVehicle, {
                    options = {
                        {
                            type = "client",
                            event = "garbage:putTrashTruck",
                            icon = "fas fa-sign-in-alt",
                            label = "Put trash in truck",
                            job = "garbage",
                        },
                    },
                    distance = 3.0
                })
                currentStop = firstStop
                currentStopNum = 1
                amountOfBags = totalBags
                isWorking = true
                exports['qb-target']:RemoveZone('trashcans')
                SetGarbageRoute()
                QBCore.Functions.Notify("You have $"..Config.TruckPrice..", deposit paid!")
                QBCore.Functions.Notify("You have started working, location marked on GPS!")
                Wait(10)
            end, coords, true)
        else
            QBCore.Functions.Notify("You have not enough money for the deposit.. Deposit costs are $"..Config.TruckPrice)
        end
    end)
end)


RegisterNetEvent('garbage:returnTruck', function()
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    local distance = #(pos - vehCoords)
    local InVehicle = IsPedInAnyVehicle(ped, false)
    if distance < 30.5 then
        if InVehicle then
            QBCore.Functions.TriggerCallback('garbagejob:server:EndShift', function(endShift)
                if endShift then
                    BringBackCar()
                    QBCore.Functions.Notify("Truck returned, collect your payslip to recieve your pay and deposit back!")
                else
                    QBCore.Functions.Notify("You have no deposit paid on this vehicle..")
                    currentStopNum = 0
                    currentStop = 0
                end
            end, pos)
        end
    else
        QBCore.Functions.Notify("You Are Not Near Garbage Depot", "error", 2500) -- [text] = message, [type] = primary | error | success, [length] = time till fadeout.
    end
end)