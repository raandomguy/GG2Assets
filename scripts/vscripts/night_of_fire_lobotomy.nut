// File last updated 2.9.2024, update 3.3

// Helper script file to handle fireball rocket logic + huntsman arrow ignite

// I basically stole the detect projectile logic from PopExt's customattributes.
// Credit to Royal who wrote the original code RocketPenetration from PopExt.
PopExt.AddRobotTag("bombi_explosion", {
	OnSpawn = function(bot,tag) {
		local wep = bot.GetActiveWeapon()
		wep.ValidateScriptScope()
		local wepScope = wep.GetScriptScope()

		wepScope.last_fire_time <- 0.0
		wepScope.forceAttacking <- false

		wepScope.CheckWeaponFire <- function() {
			local fire_time = GetPropFloat(self, "m_flLastFireTime")
			if (fire_time > last_fire_time && !forceAttacking) {
				local owner = self.GetOwner()
				if (owner) {
					OnShot(owner)
				}
				last_fire_time = fire_time
			}
			return
		}

		wepScope.FindRocket <- function(owner) {
			local entity = null
			for (local entity; entity = FindByClassnameWithin(entity, "tf_projectile_*", owner.GetOrigin(), 500);) {
				if (entity.GetOwner() != owner) {
					continue
				}
				entity.ValidateScriptScope()
				return entity
			}
			return null
		}

		wepScope.OnShot <- function(owner) {
			local rocket = FindRocket(owner)

			if (rocket == null) {
				return
			}

			PopExtUtil.SetDestroyCallback(rocket, function(){
				local impactPoint = self.GetOrigin()
				SpawnEntityFromTable("info_particle_system",
				{
					origin = impactPoint
					start_active = 1
					effect_name = "bombinomicon_burningdebris_halloween"
				})
			})
		}
		PopExtUtil.AddThinkToEnt(wep, "CheckWeaponFire")
	}
})

CustomAttributes.TakeDamagePostTable["night_of_fire_lobotomy_bombi_explosion_ignite_on_hit"] <- function(params) {

	local victim = GetPlayerFromUserID(params.userid)
	local attacker = GetPlayerFromUserID(params.attacker)

	if (victim == null || attacker == null || !victim.IsPlayer() || victim.IsInvulnerable() || attacker == victim || !attacker.IsBotOfType(TF_BOT_TYPE) || !attacker.HasBotTag("bombi_explosion") ) return

	PopExtUtil.Ignite(victim)

}

PopExt.AddRobotTag("arrow_ignite", {
	OnSpawn = function(bot,tag) {
		bot.ValidateScriptScope()
		local scope = bot.GetScriptScope()
		local wep = bot.GetActiveWeapon()

		scope.PlayerThinkTable["night_of_fire_lobotomy_arrow_ignite"] <- function() {
			if (wep.GetClassname() != "tf_weapon_compound_bow") return

			if (HasProp(wep, "m_bArrowAlight") && !GetPropBool(wep, "m_bArrowAlight"))
				SetPropBool(wep, "m_bArrowAlight", true)
		}
	}
})
