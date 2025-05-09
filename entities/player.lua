local Player = {}

 function Player.new()
     return {
         x = 100, y = 300,
         width = 50, height = 50,
         speed = 200,
         health = 100,
         maxHealth = 100,
         alive = true,
         attackDamage = 5,
         attackRange = 120,
         attackCD = 1,
         attackTimer = 0,
         rangedCD = 2,
         rangedTimer = 0,
         rangedDamage = 2,
         teleportCD = 12,
         teleportTimer = 0,
         dodgeCD     = 4,
         dodgeTimer  = 0,
     }
 end

return Player
