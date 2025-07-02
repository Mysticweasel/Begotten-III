iif not DrGBase then return end
ENT.Base = "drgbase_nextbot" -- DO NOT TOUCH (obviously)
-- Misc --
ENT.PrintName = "Wailing Burster"
ENT.Category = "Begotten DRG"
ENT.Models = {"models/begotten/thralls/another.mdl"}
ENT.BloodColor = BLOOD_COLOR_RED
ENT.RagdollOnDeath = false

-- Sounds --
ENT.OnDamageSounds = {"begotten/npc/suitor/attack_launch01.mp3", "begotten/npc/suitor/attack_launch02.mp3"}
ENT.OnDeathSounds = {"begotten/npc/suitor/amb_alert01.mp3"}
ENT.PainSounds = ENT.OnDamageSounds
ENT.ChargeSound = "begotten/npc/suitor/attack_launch02.mp3"

-- Stats --
ENT.SpawnHealth = 50
ENT.SpotDuration = 15
ENT.bulletScale = 1.0

-- Explosion --
ENT.ExplosionDamage = 50
ENT.ExplosionRadius = 150
ENT.ExplosionDelay = 2.0

-- AI --
ENT.RangeAttackRange = 0
ENT.MeleeAttackRange = 100
ENT.ReachEnemyRange = 80
ENT.AvoidEnemyRange = 0
ENT.HearingCoefficient = 0.5
ENT.SightFOV = 300
ENT.SightRange = 1024
ENT.XPValue = 50

-- Relationships --
ENT.Factions = {FACTION_ZOMBIES}

-- Movement --
ENT.UseWalkframes = true
ENT.RunAnimation = ACT_RUN
ENT.RunAnimRate = 1

-- Climbing --
ENT.ClimbLadders = true
ENT.ClimbProps = true
ENT.ClimbLedges = true
ENT.ClimbLedgesMaxHeight = 300
ENT.ClimbSpeed = 100
ENT.ClimbUpAnimation = "run_all_grenade"
ENT.ClimbOffset = Vector(-14, 0, 0)

-- Detection --
ENT.EyeBone = "ValveBiped.Bip01_Spine4"
ENT.EyeOffset = Vector(7.5, 0, 5)

-- Possession --
ENT.PossessionEnabled = true
ENT.PossessionMovement = POSSESSION_MOVE_8DIR
ENT.PossessionViews = {
  {
    offset = Vector(0, 30, 20),
    distance = 100
  },
  {
    offset = Vector(7.5, 0, 0),
    distance = 0,
    eyepos = true
  }
}
ENT.PossessionBinds = {
  [IN_ATTACK] = {{
    coroutine = true,
    onkeydown = function(self)
      self:StartSuicideSequence()
    end
  }}
}

if SERVER then

function ENT:CustomInitialize()
  self:SetDefaultRelationship(D_HT)
  self:EmitSound("begotten/npc/suitor/enabled01.mp3", 100)
end

function ENT:OnIdle()
  if not self.nextCry or self.nextCry < CurTime() then
    self.nextCry = CurTime() + math.random(4, 8)
    self:EmitSound("begotten/npc/suitor/amb_idle01.mp3", 75, math.random(90, 110))
    self:AddPatrolPos(self:RandomPos(1500))
  end
end

function ENT:OnMeleeAttack(enemy)
  if self:GetPos():Distance(enemy:GetPos()) <= self.MeleeAttackRange then
    self:StartSuicideSequence()
  end
end

function ENT:OnDeath(dmg, delay, hitgroup)
  self:StartSuicideSequence(true, dmg:GetAttacker())
end

function ENT:StartSuicideSequence(fromDeath, attacker)
  if self.HasStartedExplosion then return end
  self.HasStartedExplosion = true

  self:EmitSound(self.ChargeSound, 100, 100)

  timer.Simple(self.ExplosionDelay, function()
    if not IsValid(self) then return end
    self:SuicideExplosion(fromDeath, attacker)
  end)
end

function ENT:SuicideExplosion(fromDeath, attacker)
  if self.HasExploded then return end
  self.HasExploded = true

  local pos = self:GetPos()

  local effectData = EffectData()
  effectData:SetOrigin(pos)
  util.Effect("Explosion", effectData)

  util.BlastDamage(self, self, pos, self.ExplosionRadius, self.ExplosionDamage)
  self:EmitSound("ambient/explosions/explode_8.wav", 100, 100)

  ParticleEffectAttach("doom_dissolve", PATTACH_POINT_FOLLOW, self, 0)

  timer.Simple(1.6, function()
    if not IsValid(self) then return end

    ParticleEffectAttach("doom_dissolve_flameburst", PATTACH_POINT_FOLLOW, self, 0)
    self:EmitSound("begotten/npc/burn.wav")

    if cwRituals and cwItemSpawner and not hook.Run("GetShouldntThrallDropCatalyst", self) then
      local lootPool = {}
      local spawnable = cwItemSpawner:GetSpawnableItems(true)

      for _, itemTable in ipairs(spawnable) do
        if itemTable.category == "Catalysts" then
          if itemTable.itemSpawnerInfo and not itemTable.itemSpawnerInfo.supercrateOnly then
            table.insert(lootPool, itemTable)
          end
        end
      end

      local randomItem = lootPool[math.random(1, #lootPool)]
      if randomItem then
        local itemInstance = item.CreateInstance(randomItem.uniqueID)
        if itemInstance then
          local entity = Clockwork.entity:CreateItem(nil, itemInstance, self:GetPos() + Vector(0, 0, 32))
          entity.lifeTime = CurTime() + config.GetVal("loot_item_lifetime")
          table.insert(cwItemSpawner.ItemsSpawned, entity)
        end
      end
    end

    self:Remove()
  end)
end

function ENT:ShouldIgnore(ent)
  if ent:IsPlayer() and (ent.possessor or ent.victim) then
    return true
  end
end

end

DrGBase.AddNextbot(ENT)
