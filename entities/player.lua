local Player = {}

function Player.new()
    return {
        x = 100, y = 300,
        width = 50, height = 50,
        speed = 200,
        health = 20,
        maxHealth = 20,
        alive = true,
        attackDamage = 1,
        attackRange = 60,
        attackCD = 1,
        attackTimer = 0,
        rangedCD = 2,
        rangedTimer = 0,
        rangedDamage = 2,
        teleportCD = 5,
        teleportTimer = 0,
    }
end

return Player
