---@diagnostic disable: unused-local
--!nocheck

local FastCast = {}
FastCast.DebugLogging = false
FastCast.VisualizeCasts = false
FastCast.__index = FastCast
FastCast.__type = "FastCast" -- For compatibility with TypeMarshaller

FastCast.HighFidelityBehavior = {
	Default = 1,
	Always = 3
}

local ActiveCastStatic = require(script.ActiveCast)
local Signal = require(script.Signal)
local table = require(script.Table)

local ERR_NOT_INSTANCE = "Cannot statically invoke method '%s' - It is an instance method. Call it on an instance of this class created via %s"
local ERR_INVALID_TYPE = "Invalid type for parameter '%s' (Expected %s, got %s)"
local FC_VIS_OBJ_NAME = "FastCastVisualizationObjects"
local ERR_OBJECT_DISPOSED = "This Caster has been disposed. It can no longer be used."

-- This will inject all types into this context.
local TypeDefs = require(script.TypeDefinitions)
type CanPierceFunction = TypeDefs.CanPierceFunction
type GenericTable = TypeDefs.GenericTable
export type Caster = TypeDefs.Caster
export type FastCastBehavior = TypeDefs.FastCastBehavior
type CastTrajectory = TypeDefs.CastTrajectory
type CastStateInfo = TypeDefs.CastStateInfo
type CastRayInfo = TypeDefs.CastRayInfo
export type ActiveCast = TypeDefs.ActiveCast

-- Tell the ActiveCast factory module what FastCast actually *is*.
ActiveCastStatic.SetStaticFastCastReference(FastCast)

-- Constructor.
function FastCast.new(): Caster
	return setmetatable({
		LengthChanged = Signal.new("LengthChanged"),
		RayHit = Signal.new("RayHit"),
		RayPierced = Signal.new("RayPierced"),
		CastTerminating = Signal.new("CastTerminating"),
		WorldRoot = workspace
	}, FastCast)
end

function FastCast.newBehavior(): FastCastBehavior
	return {
		RaycastParams = nil,
		Acceleration = Vector3.new(),
		MaxDistance = 1000,
		CanPierceFunction = nil,
		HighFidelityBehavior = FastCast.HighFidelityBehavior.Default,
		HighFidelitySegmentSize = 0.5,
		CosmeticBulletTemplate = nil,
		CosmeticBulletProvider = nil,
		CosmeticBulletContainer = nil,
		AutoIgnoreContainer = true
	}
end

local DEFAULT_DATA_PACKET = FastCast.newBehavior()
function FastCast:Fire(origin: Vector3, direction: Vector3, velocity: Vector3 | number, castDataPacket: FastCastBehavior?): ActiveCast
	if castDataPacket == nil then castDataPacket = DEFAULT_DATA_PACKET end

	local cast = ActiveCastStatic.new(self, origin, direction, velocity, castDataPacket)
	cast.RayInfo.WorldRoot = self.WorldRoot
	return cast
end

-- Export
return FastCast