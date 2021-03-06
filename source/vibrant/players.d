module players;

import std.math;
import gfm.math;
import oldfonts;
import palettes;
import vga2d;
import utils;
import globals;
import sdl.all;
import mousex;
import std.stdio;
import joy, sound;
import game;
import particles;
import powerup;
import map;
import bullettime;
import camera;

// Attitudes

enum Attitude {HUMAN, AGGRESSIVE, FEARFUL, KAMIKAZE, OCCUPIED };

enum float MAX_DESTROY = 32 / 60.0f;

enum Anomaly {ATTRACTOR, WALL};

final class Player
{
    enum int MAX_DRAGGED_POWERUPS = 4; // can't drag more than that powerup
    static const MAX_TAIL = 100;

    Game game;
    Camera _camera;
    bool dead;

    vec2f[MAX_TAIL] positions; // pos[0] = current   pos[1] = last frame position

    vec2f currentPosition()
    {
        return positions[0];
    }

    vec2f lastPosition()
    {
        return positions[1];
    }

    vec2f mov;
    //vec2f lastPos;
    float armsPhase;
    float angle, vangle;
    vec3f color;
    float life;
    float baseVelocity; // velocity at size 7
    float shipSize;
    float energy;
    float waitforshootTime;
    float destroy;
    Attitude attitude;
    Anomaly anomaly;
    bool turbo;
    float energygain;
    int weaponclass;
    float shieldAngle;
    float invincibility;
    float livingTime; // livingTime, modulo 256 sec
    float mapEnergyGain;
    bool bounced;
    bool isHuman;
    bool isAnomaly;
    Player _catchedPlayer;
    float _catchedPlayerDistance;
    Xorshift32* _random;

    private Powerup[MAX_DRAGGED_POWERUPS] _draggedPowerups;
    private int _numDraggedPowerups;
    float engineExcitation;


    static const float SHIELD_SIZE_FACTOR = 2.0f;
    static const float INVICIBILITY_SIZE_FACTOR = 2.0f;
    static const float LIVING_TIME_CYCLE = 256.0f;

    this(Game game, bool isHuman_, vec2f pos, float angle)
    {
        this.isHuman = isHuman_;

        this.positions[] = pos;
        this.angle = angle;
        this.game = game;
        this.mapEnergyGain = 0.0f;
        _random = game.random();
        _camera = game.camera();
        vangle = 0.0f;
        mov = vec2f(0.0f);
        dead = false;
        destroy = 0.0f;
        life = 1;
        engineExcitation = 0;


        turbo = false;
        shipSize = SHIP_MIN_SIZE + ((*_random).nextFloat() ^^ 2) * (SHIP_MAX_SIZE - SHIP_MIN_SIZE);
        weaponclass = 1 + cast(int)round(((*_random).nextFloat() ^^ 2)*2);
        energygain = BASE_ENERGY_GAIN * 1.5f;
        shieldAngle = (*_random).nextFloat;
        armsPhase = (*_random).nextAngle;

        livingTime = 0.0f;

        _draggedPowerups[] = null;
        _numDraggedPowerups = 0;
        _catchedPlayer = null;

        if (isHuman)
        {
            life = 1.0;
            weaponclass = 1;
            attitude = Attitude.HUMAN;
            shipSize = SHIP_MIN_SIZE;
            color = vec3f(1, 0, 0);
            baseVelocity = PLAYER_BASE_VELOCITY;
            waitforshootTime = 0.0f;
            invincibility = level > 0 ? 2.0f : 0.0f;
            energy = 0;
        }
        else
        {
            energy = ENERGYMAX;
            waitforshootTime = (*_random).nextFloat;
            invincibility = 0.0f;

            vec3f colorchoose()
            {
                float r = void, g = void, b = void;
                bool ok = false;
                do
                {
                    r = (*_random).nextFloat;
                    g = (*_random).nextFloat;
                    b = (*_random).nextFloat;
                    ok = (r+g+b > 1.0f) && (r*g*b < 0.5f);
                } while(!ok);
                return vec3f(r, g, b);
            }
            color = colorchoose;
            angle = (*_random).nextFloat * (2 * PI);

            // AI have slightly different velocities
            baseVelocity = PLAYER_BASE_VELOCITY * (1.0f + ((*_random).nextFloat - 0.5f) * 0.1f);

            attitude = ((*_random).nextRange(2) == 0) ? Attitude.OCCUPIED : Attitude.FEARFUL;
        }
    }
/*
  this(Game game, bool isAnomaly_, vec2f pos, Anomaly anomaly_)
    {
        this.isAnomaly = isAnomaly_;
        this.Anomaly = anomaly_;
        this.positions[] = pos;
        this.game = game;

        _random = game.random();

        mov = vec2f(0.0f);
        dead = false;
        destroy = 0.0f;
        life = 1;
        engineExcitation = 0;

        livingTime = 0.0f;
    }
*/
        
    
    void cleanup()
    {
        stopDraggingPlayer();
        stopDraggingPowerups();
    }

    void checkDragInvariant()
    {
        // check for non-presence
        for (int i = 0; i < _numDraggedPowerups; ++i)
        {
            assert(_draggedPowerups[i] !is null);
            assert(_draggedPowerups[i].getDragger() is this);
        }
    }

    void startDragPowerup(Powerup p)
    {
        debug checkDragInvariant();
        assert(_numDraggedPowerups < MAX_DRAGGED_POWERUPS);

        // check for non-presence
        for (int i = 0; i < _numDraggedPowerups; ++i)
            assert(_draggedPowerups[i] !is p);

        _draggedPowerups[_numDraggedPowerups++] = p;

        game.soundManager.playSound(p.pos, 0.7f + (*_random).nextFloat * 0.3f, SOUND.CATCH_POWERUP);
        debug checkDragInvariant();
    }

    void stopDragPowerup(Powerup p)
    {
        debug checkDragInvariant();
        bool found = false;
        int i = 0;
        while (i < _numDraggedPowerups)
        {
            if (p is _draggedPowerups[i])
            {
                assert(!found);
                found = true;
                --_numDraggedPowerups;
                _draggedPowerups[i] = _draggedPowerups[_numDraggedPowerups];
                _draggedPowerups[_numDraggedPowerups] = null;
            }
            else
            {
                i++;
            }
        }
        assert(found);
        debug checkDragInvariant();
    }

    void stopDraggingPlayer()
    {
        if (_catchedPlayer !is null)
        {
            _catchedPlayer._catchedPlayer = null;
            _catchedPlayer = null;
        }
    }

    void stopDraggingPowerups()
    {
        int i = 0;
        while (_numDraggedPowerups > 0)
        {
            assert(_draggedPowerups[0].getDragger() is this);
            _draggedPowerups[0].setDragger(null);
            ++i;
        }
        debug checkDragInvariant();
    }

    float invMass()
    {
        return SHIP_MIN_SIZE / shipSize;
    }

    float mass()
    {
        return shipSize / SHIP_MIN_SIZE;
    }

    bool isInvincible()
    {
        return invincibility > 0;
    }

    bool isAlive()
    {
        return (destroy == 0);
    }

    float effectiveSize()
    {
        if (invincibility > 0)
        {
            return shipSize * INVICIBILITY_SIZE_FACTOR;
        }

        if (life > 1.00001)
        {
            return shipSize * SHIELD_SIZE_FACTOR;
        } else
        {
            return shipSize;
        }
    }

    bool isVulnerable() // will explode at next hit
    {
        return life < DAMAGE_MULTIPLIER * BULLET_DAMAGE * damageMultiplier();
    }

    bool isReallyReallyVulnerable() // will explode at next hit
    {
        return life * 8.0f < DAMAGE_MULTIPLIER * BULLET_DAMAGE * damageMultiplier();
    }

    vec3f maincolor()
    {
        vec3f r = void;
        float expo = shipSize - 6.0;

        if (isVulnerable() && (cos((2 * PI) * 6.0f * livingTime) >= 0))
        {
            r = vec3f(1.0f) - color;
        }
        else
        {
            r = color;
        }

        if (attitude == Attitude.KAMIKAZE)
        {
            r = vec3f(1.0f, r.y, r.z);
        }

        if (invincibility > 0)
        {
            r = vec3f(r.x, r.y, lerp(r.z, 1.0f, std.algorithm.min(1.0f, invincibility)));
        }

        r.z = std.algorithm.min(1.0f, r.z + mapEnergyGain * 0.1f);

        return r;
    }

    static bool collisioned(Player s1, Player s2)
    {
        // trick: collision do not happen outside of vision :)
        //if ((!player._camera.canSee(s1.currentPosition)) || (!player._camera.canSee(s2.currentPosition)))
        //    return false;
        // no triks!
        return s1.currentPosition.squaredDistanceTo(s2.currentPosition) < ((s1.effectiveSize + s2.effectiveSize) ^^ 2);
    }

    void show()
    {
        const ENGINE_ARMS = 3;
        if ((dead) || (!_camera.canSee(currentPosition)))
        {
            return;
        }

        if (_catchedPlayer !is null)
        {
            GL.begin(GL.LINES);
                GL.color = RGBAF(0xff606060);
                vertexf(currentPosition);
                vertexf(_catchedPlayer.currentPosition);
            GL.end();
        }

        pushmatrix;

        GL.enable(GL.BLEND);

        // tail
        {
            float lastDl = 0.0f;
            GL.begin(GL.TRIANGLE_STRIP);
            for (int i = 0; i < MAX_TAIL - 1; ++i)
            {
                float df = i / cast(float)(MAX_TAIL - 1);

                vec2f B = positions[i];
                vec2f E = positions[i + 1];
                vec2f diff = B - E;
                double dl = diff.length();

                lastDl += (dl - lastDl) * 0.4f; // smoth dl since it's too discontinuous

                float alpha = gfm.math.clamp(0.06f * (lastDl - 5) * (df * (1-df)) * (1 - destroy / MAX_DESTROY), 0.0f, 0.3f);


                GL.color = vec4f(color, alpha);

                if (dl < 1e-3f)
                    break;


                float expectedWidthN = shipSize * (df * (1-df));
                expectedWidthN = std.algorithm.min(expectedWidthN, lastDl);
                diff.normalize();

                vec2f D = B + vec2f(diff.y, -diff.x) * expectedWidthN;
                vec2f F = B + vec2f(-diff.y, diff.x) * expectedWidthN;
                vertexf(D);
                vertexf(F);
            }
            vertexf(positions[MAX_TAIL - 1]);
            GL.end();
        }

        vga2d.translate(currentPosition);

        scale(shipSize, shipSize);

        rotate(-angle + PI_2);


        // shadow
        {

            GL.begin(GL.TRIANGLE_FAN);

            GL.color = vec4f(0.0f,0.0f,0.0f,0.5f);
            vertexf(0,0);
            GL.color = vec4f(0.0f,0.0f,0.0f,0.0f);
            const SIZE = 2;
            for (int i = 0; i < 32; ++i)
            {
                float fi = i / 32.0f;
                float angle = (2 * PI) * fi;
                float sina = void, cosa = void;
                sina = sin(angle);
                cosa = cos(angle);
                vertexf(cosa * SIZE, sina * SIZE);
            }
            GL.end();
        }

        // draw engine activity
        if (engineExcitation > 0)
        {
            GL.begin(GL.TRIANGLE_FAN);
            vec2f center = vec2f(0.0f, -0.75f);
            vec3f engineCol = particleColor() * 0.75f + 0.25f * vec3f(1.0f, 1.0f, 0.0f);

            GL.color = vec4f(engineCol, engineExcitation * 0.75f);
            vertexf(center);
            const SIZE = 0.6f;
            GL.color = vec4f(0.0f,1.0f,1.0f,0.0f);
            for (int i = 0; i < 9; ++i)
            {
                float fi = i / 9.0f;
                float angle = (2 * PI) * fi;
                float sina = void, cosa = void;
                sina = sin(angle);
                cosa = cos(angle);
                vertexf(center.x + cosa * SIZE, center.y + sina * SIZE);
            }
            GL.end();
        }

        // invincibility shield
        if (isInvincible())
        {
            GL.begin(GL.TRIANGLE_FAN);

            float alpha = 0.7f * (0.3f + 0.7f * std.algorithm.min(3.0f, player.invincibility) / 3.0f);

            GL.color = vec4f(0.0f,0.0f,0.1f, alpha);
            vertexf(0,0);
            for (int i = 0; i < 32; ++i)
            {
                float fi = i / 32.0f;
                float angle = (2 * PI) * fi;
                float sina = void, cosa = void;
                sina = sin(angle);
                cosa = cos(angle);
                vertexf(cosa * INVICIBILITY_SIZE_FACTOR, sina * INVICIBILITY_SIZE_FACTOR);
            }
            GL.end();

            pushmatrix;

            rotate(shieldAngle);
            GL.begin(GL.LINE_STRIP);


            for (int i = 0; i <= 32; ++i)
            {
                float fi = i / 32.0f;
                float angle = (2 * PI) * fi;
                vec3f c = lerp(lerp(vec3f(0,0,1), color, fi), vec3f(0), (i+1) / 32.0f);
                GL.color = vec4f(c, alpha);
                float sina = void, cosa = void;
                sina = sin(angle);
                cosa = cos(angle);
                vertexf(cosa * INVICIBILITY_SIZE_FACTOR, sina * INVICIBILITY_SIZE_FACTOR);
            }
            GL.end();
            popmatrix;

        }

        // life shield
        if ((life > 1.00001) && (!isInvincible()))
        {
            pushmatrix;

            rotate(shieldAngle);

            GL.begin(GL.LINE_STRIP);

            for (int i = 0; i <= 32; ++i)
            {
                float fi = i / 32.0f;
                float angle = (2 * PI) * fi;
                vec3f c = lerp(  lerp(vec3f(1,1,0), color, fi), vec3f(0), (i+1) / 32.0f);
                GL.color = vec4f(c, (life - 1) * 0.7f );
                float cosa = void, sina = void;
                sina = sin(angle);
                cosa = cos(angle);
                vertexf(cosa * SHIELD_SIZE_FACTOR, sina * SHIELD_SIZE_FACTOR);
            }
            GL.end();
            popmatrix;
        }

        // helix
        if (destroy == 0)
        {
            pushmatrix;

            vga2d.translate(0.0f,1.0f);

            vec3f hcolor = 0.5f * color + 0.5f * vec3f(1.0f, 0.0f, 1.0f);



            rotate( armsPhase + PI * 20.0f * energy / cast(float)(ENERGYMAX));

            for (int j = 0; j < ENGINE_ARMS; ++j)
            {
                GL.begin(GL.LINES);
                GL.color = hcolor;
                vertexf(0,0);

                float px = 0.01;
                float py = 0.01;

                float baseangle = j * 6.2831853f / 3.0f;
                float dist = ((energygain - BASE_ENERGY_GAIN) / BASE_ENERGY_GAIN) * 0.03f + 0.18f;

                for (int i = 0; i < 4; ++i)
                {
                    GL.color = hcolor / (1.0f + i);
                    float ang = baseangle + 0.6f;

                    float sina = void, cosa = void;
                    sina = sin(ang);
                    cosa = cos(ang);
                    px = px + cosa * dist;
                    py = py + sina * dist;
                    vertexf(px,py);

                    if (i < 3)
                        vertexf(px,py);
                }
                GL.end();
            }

            popmatrix;

            // draw arms
            {
                vec3f armsColor = lerp(color, RGBF(ColorROL(Frgb(color), cast(byte)(12 + weaponclass))), 0.5f);
                vec3f armsColorDark = lerp(armsColor, vec3f(0.3f, 0.3f, 0.4f), 0.5f);// * 0.4f;
                float wingswidth = std.algorithm.min(3, weaponclass);
                pushmatrix;
                rotate(-waitforshootTime*12);


                GL.begin(GL.TRIANGLES);
                {
                    auto a = vec2f(-0.72f, -0.143f);
                    auto b = vec2f(-0.29f, -0.143f);
                    auto c = vec2f(-0.51f-0.29f*weaponclass,0.43f+0.29f*weaponclass);
                    auto d = (a + b) * 0.5f;

                    GL.color = armsColorDark;
                    vertexf(a);
                    vertexf(c);
                    vertexf(d);

                    GL.color = armsColor;
                    vertexf(b);
                    vertexf(c);
                    vertexf(d);
                }
                GL.end();

                rotate(waitforshootTime*24);

                GL.begin(GL.TRIANGLES);
                {
                    auto a = vec2f(0.72f, -0.143f);
                    auto b = vec2f(0.29f, -0.143f);
                    auto c = vec2f(0.51f+0.29f*weaponclass,0.43f+0.29f*weaponclass);
                    auto d = (a + b) * 0.5f;

                    GL.color = armsColorDark;
                    vertexf(a);
                    vertexf(c);
                    vertexf(d);

                    GL.color = armsColor;
                    vertexf(b);
                    vertexf(c);
                    vertexf(d);
                }
                GL.end();
                popmatrix;
            }

            // dram main part
            {
                GL.begin(GL.TRIANGLES);
                {
                    vec3f c = maincolor();
                    GL.color = c;
                    vertexf(0.0f,1.0f);
                    vertexf(-0.72f,-1.0f);

                    GL.color = lerp(c, vec3f(1,1,1), 0.5f);
                    vertexf(0.0f,-0.5f);
                    vertexf(0.0f,-0.5f);

                    GL.color = c;
                    vertexf(0.72f,-1.0f);
                    vertexf(0.0f,1.0f);

                    // thrust
                    GL.color = lerp(c, vec3f(0.2f, 0.6f, 0.6f),  0.5f);
                    float bb = baseVelocity / PLAYER_BASE_VELOCITY;
                    vertexf(0.0f,-0.5f);
                    vertexf(0.42f,-0.5f);
                    vertexf(0.12f,-0.75f - bb * 0.25f);
                    vertexf(0.0f,-0.5f);
                    vertexf(-0.42f,-0.5f);
                    vertexf(-0.12f,-0.75f - bb * 0.25f);
                }
                GL.end();

                GL.begin(GL.QUADS);
                {
                    vec3f col = lerp(color, RGBF(ColorROR(Frgb(color), 24)), 0.5f);
                    GL.color = lerp(col, vec3f(0.0f), 0.95f);
                    vertexf(0.0,0.5);
                    GL.color = col;
                    vertexf(-0.36,-0.5);
                    GL.color = lerp(col, vec3f(1.0f), 0.8f);
                    vertexf(0.0,-0.643);
                    GL.color = col;
                    vertexf(0.36,-0.5);
                }
                GL.end();
            }
        }
        else
        {
            GL.begin(GL.LINES);
            for (int i = 0; i < 6; ++i)
            {

                if ((*_random).nextRange(4) == 0)
                {
                    GL.color = vec4f(0.5f,0.5f,0.5f,1);
                }
                else
                {
                    GL.color = vec4f(0,0,0,1);
                }
                float d = (*_random).nextFloat * destroy / 7.0f;
                vertexf(0.0,0.0);
                float angle = (*_random).nextAngle;
                float cosa = void, sina = void;
                cosa = cos(angle);
                sina = sin(angle);
                vertexf(cosa * d, sina * d);
            }
            GL.end();
        }
        popmatrix;

        GL.check();
    }

    // damage multiplier, with ship size in account
    float damageMultiplier()
    {
        return pow(shipSize - (SHIP_MIN_SIZE - 1),-2.0 / 3.0);
    }

    float damageToExplode()
    {
        return (life + 1e-2f) / (damageMultiplier() * DAMAGE_MULTIPLIER);
    }

    float trapDamage()
    {
        return (life + 1e-2f) * 0.1f + 0.5;
    }    
    
    void damage(float amount)
    {
        if (invincibility > 0) return;

        amount *= DAMAGE_MULTIPLIER;
        life = life - amount * damageMultiplier();

        if (life <= 0)
        {
            explode(amount * 0.5 + 0.25f);
            if (isHuman)
            {
                BulletTime.exit();
            }

            life = -0.001;
        }
    }

    uint particleColor()
    {
        vec3f r = color;
        r.z = std.algorithm.min(1.0f, r.z + mapEnergyGain * 0.02f);
        return Frgb(r);
    }

    void explode(float explode_power)
    {
        if (isAlive())
        {
            game.soundManager.playSound(currentPosition, 0.5f + 0.3f * (*_random).nextFloat, SOUND.EXPLODE);

            explode_power = clamp(explode_power, 0.0f, 1.0f);
            destroy = 0.0001f;
            cleanup();
            angle = PI + normalizeAngle(angle - PI);

            int nParticul = cast(int)round((100 + (*_random).nextRange(60)) * PARTICUL_FACTOR * (shipSize / SHIP_MIN_SIZE));
            auto cc = particleColor();
            for (int i = 0; i <= nParticul; ++i)
            {
                int life = cast(int)round(sqr((*_random).nextFloat) * (*_random).nextRange(800 - cast(int)round(400 * explode_power))) + 5;
                game.particles.add(currentPosition, sqr((*_random).nextFloat) * mov * invMass,  0, 0, (*_random).nextAngle,
                                   (sqr((*_random).nextFloat) + sqr((*_random).nextFloat) * 0.3f) * 7.0f * explode_power,
                            cc, life);
            }

            // move nearby powerups
            for (int i = 0; i < powerupIndex; ++i)
            {
                Powerup m = powerupPool[i];
                assert(m.getDragger() !is this);
                float d = currentPosition.squaredDistanceTo(m.pos);
                m.mov += 100 * (m.pos - currentPosition) / (d + 1.0f);
            }

            // move nearby players
            void movePlayer(Player p)
            {
                if (p is null) return;
                if (p is this) return;
                if (p.dead) return;
                float d = currentPosition.squaredDistanceTo(p.currentPosition);
                p.mov += (((*_random).nextFloat + (*_random).nextFloat) * 0.5f) * sqr(mass()) * 200 * (p.currentPosition - currentPosition) / (d + 100.0f);
            }

            for (int i = 0; i < NUMBER_OF_IA; ++i)
            {
                movePlayer(ia[i]);
            }
            //nope
            //movePlayer(player);

            int nPowerup = 1 + cast(int)round((*_random).nextFloat * level * 0.08);
            if (nPowerup > 2)
                nPowerup = 2;
            for (int i = 0; i < nPowerup; ++i)
            {
                float t = (*_random).nextFloat;
                game.addPowerup(currentPosition, mov * t, (*_random).nextAngle, (*_random).nextFloat * 5);
            }
        }
    }

    bool buyWithEnergy(float amount)
    {
        if (energy < amount)
            return false;

        energy -= amount;
        return true;
    }

    void shoot()
    {
        if (weaponclass == 0) return;
        if (waitforshootTime > 0.0f) return;


        if (!buyWithEnergy(BULLET_COST))
            return;

        if (isAlive())
        {
            float baseangle = angle;

            //int forwardBullet = std.algorithm.min(weaponclass, 3);
            int forwardBullet = std.algorithm.min(weaponclass, 31666); // hell yeah!
            int mguided = isHuman ? 50 : 20;


            for (int i = 0; i < forwardBullet; ++i)
            {
                float mangle = baseangle + 0.07f * (i - (forwardBullet-1) * 0.5f);

                float mspeed = ((forwardBullet == 3) && (i == 1)) ? BULLET_BASE_SPEED + 0.5 : BULLET_BASE_SPEED;
                if (isHuman)
                    mspeed *= 1.25;

                vec2f vel = mov;
                vec2f dir = polarOld(mangle, 1.0f);
                vec2f v = mspeed * dir + vel;


                vec2f mpos = currentPosition + dir * shipSize;

                auto mcolor = (RGBF(0xFFA0A0) + color) * 0.5f;
                Player owner = this;
                game.addBullet(mpos, v, mcolor, mangle, mguided, owner);
            }

            mov -= polarOld(baseangle, 1.0f) * 0.5f; // recul

            waitforshootTime = RELOADTIME;
            game.soundManager.playSound(currentPosition, 1.0f, SOUND.SHOT);
        }
    }

    
    void release_dummies()
    {
        if ((*_random).nextFloat > 0.1f) return;


        if (isAlive()) 
        {
            vec2f mpos = currentPosition;
            Player owner = this;
            game.addDummies(mpos, owner);
        }

    }    

    void move(Map map, double dt)
    {
        auto BUMPFACTOR = 1.414;
        auto CONSTANT_BUMP = 0.0;
        float f = void;
        if (dead) return;

        bounced = false;


        for (int i = MAX_TAIL - 1; i > 0; --i)
        {
            positions[i] = positions[i - 1];
        }

        livingTime += dt;
        while (livingTime > LIVING_TIME_CYCLE) livingTime -= LIVING_TIME_CYCLE;

        engineExcitation *= exp3(-dt * 12);

        {
            armsPhase += dt * 0.6 * PI;

            while (armsPhase > 32.0f * (2 * PI))
            {
                armsPhase -= 64.0f * (2 * PI);
            }
        }

        angle = normalizeAngle(angle + (vangle * invMass()) * 60.0f * dt);

        vangle = vangle * exp(-dt * 0.955f);

        shieldAngle = shieldAngle + 12 * dt;

        while(shieldAngle > PI * 2)
        {
            shieldAngle -= PI * 2;
        }

        waitforshootTime -= dt;
        if (waitforshootTime < 0.0f) waitforshootTime = 0.0f;

        if (invincibility > 0)
        {
             invincibility = std.algorithm.max(0.0f, invincibility - dt);
        }

        if (energy < ENERGYMAX)
        {
            energy = energy + energygain * 60.0f * dt;
        }

        if (life < 1)
        {
            life = life + LIFEREGEN * 60.0f * dt;
            if (life > 1) life = 0.999;
        }


        if (_catchedPlayer !is null)
        {
            float d = _catchedPlayer.currentPosition.squaredDistanceTo(currentPosition);
            if (d > 1e-3f)
            {
                _catchedPlayerDistance -= dt * 5.0f; // like TRAP
                if (_catchedPlayerDistance < 1.0f) _catchedPlayerDistance = 1.0f;
                _catchedPlayer._catchedPlayerDistance = _catchedPlayerDistance;

                d = sqrt(d);
                vec2f middle = (_catchedPlayer.currentPosition + currentPosition) * 0.5f;
                vec2f idealPosThis = middle + (currentPosition - middle) * _catchedPlayerDistance / d;
                vec2f idealPosOther = middle - (currentPosition - middle) * _catchedPlayerDistance / d;
                positions[0] += (idealPosThis - currentPosition) * std.algorithm.min(1.0f, 2.0f * dt);
                _catchedPlayer.positions[0] += (idealPosOther - _catchedPlayer.currentPosition) * std.algorithm.min(1.0f, 2.0f * dt);
                mov += (idealPosThis - currentPosition) * std.algorithm.min(1.0f, 0.25f * dt);
                _catchedPlayer.mov += (idealPosOther - _catchedPlayer.currentPosition) * std.algorithm.min(1.0f, 0.25f * dt);
            }
        }
        
        //positions[0] = positions[0] + mov * invMass * 60.0f * dt;
        positions[0] = positions[0] + geom.current_geom(positions[0],mov) * invMass * 60.0f * dt;

        // damping
        {
            // horrible legacy code, there is two damping, one of which is anosotropic :(
            // was unstable
            {
                const SPEEDATENUATOR = 0.00003;
                double speedAtten = clamp(1 - SPEEDATENUATOR * (abs(mov.x * mov.x * mov.x) + abs(mov.y * mov.y * mov.y)), 1e-5, 1.0);

                // It's very difficutl to replace the anisotropic damping...
                //double movL = mov.length();
                //double speedAtten = clamp(1 - SPEEDATENUATOR * movL * movL * movL, 1e-5, 1.0);

                float vFact = exp(dt * log(speedAtten) * 60.0f);
                mov *= vFact;
            }

            {
                double spF = clamp(1.0 - mov.squaredLength / sqr(SPEED_MAX), 1e-10, 1.0);
                double speedAtten2 = sqrt(spF);
                float vFact2 = exp(dt * log(speedAtten2) * 60.0f);
                mov *= vFact2;
            }
        }

        // gain energy from map borders (yes, like in the real world, just go the the edge of the World :)
        {
            mapEnergyGain = 0.0f;

            float fx = map.distanceToBorder(currentPosition);

            if (fx < 100)
            {
                mapEnergyGain += 0.4f * dt * (100 - fx) * mov.squaredLength;
            }

            energy = clamp(energy + mapEnergyGain, 0.0f, 2 * ENERGYMAX);
        }

        //  borders
        {
            int bounces = map.enforceBounds(positions[0], mov, angle, effectiveSize, BUMPFACTOR, CONSTANT_BUMP);

            bounced = bounces > 0;

            if (bounced)
            {
                stopDraggingPlayer();
            }

            if (bounces > 0)
            {
                energy = 0;
                invincibility = 0.0f;
                game.soundManager.playSound(currentPosition, 1.0f, SOUND.BORDER);
            }
        }

        if (destroy > 0.0f)
        {
            destroy += dt;

            if (destroy >= MAX_DESTROY)
            {
                dead = true;
            }
        }

        if (attitude != Attitude.HUMAN)
        {
            if ((*_random).nextFloat < 0.0025 * 60.0f * dt) attitude = Attitude.AGGRESSIVE;
            if ((*_random).nextFloat < 0.002 * 60.0f * dt) attitude = Attitude.OCCUPIED;
            if ((life < 0.42) && ((*_random).nextFloat < 0.0025 * 60.0f * dt)) attitude = Attitude.FEARFUL;
            if ((life < 0.21) && ((*_random).nextFloat < 0.01 * 60.0f * dt)) attitude = Attitude.KAMIKAZE;

            if (!player.isValidTarget()) attitude = Attitude.OCCUPIED;
        }
    }

    void becomeMad()
    {
        attitude = Attitude.KAMIKAZE;
    }

    bool isValidTarget()
    {
        return isAlive();
    }

    void intelligence(ref MouseState mouse, float dt)
    {
        if (destroy > 0) return;
        switch (attitude)
        {
            case Attitude.HUMAN:
            {
                auto axisx = joyAxis(0);
                auto axisy = joyAxis(1);
                bool isAlt = iskeydown(SDLK_LALT) || iskeydown(SDLK_RALT) || joyButton(3);
                isAlt = !isAlt; //invert strafe
                //bool isAlt = true; // always strafe

                bool isShift = iskeydown(SDLK_LSHIFT) || iskeydown(SDLK_RSHIFT);


                bool isUp = iskeydown(SDLK_UP) || iskeydown(SDLK_w);
                bool isDown = iskeydown(SDLK_DOWN) || iskeydown(SDLK_s);
                bool isLeft = iskeydown(SDLK_LEFT) || iskeydown(SDLK_a);
                bool isRight = iskeydown(SDLK_RIGHT) || iskeydown(SDLK_d);

                bool mouseLeft = 0 != (mouse.buttons & MOUSE_LEFT);
                bool mouseRight = 0 != (mouse.buttons & MOUSE_RIGHT);
                bool mouseCenter = 0 != (mouse.buttons & MOUSE_CENTER);

                bool isFire = iskeydown(SDLK_LCTRL) || iskeydown(SDLK_RCTRL) || iskeydown(SDLK_c) || mouseLeft || joyButton(1);

                if (isFire)
                {
                    shoot();
                }

                if  (   iskeydown(SDLK_q) )                
                {
                    release_dummies();
                }            
                
                
                
                // continuous drag, except if space pressed
                // TODO mousecenter and joystik
                if  (   iskeydown(SDLK_SPACE)
                    || (joyButton(2) && lastTimeButton2WasOff)
                    || iskeydown(SDLK_z)
                    || mouseCenter )
                {
                    // drag();
                } else {
                    drag();
                }

                mouse.buttons &= (~MOUSE_CENTER); // disable continuous powerup catch


                lastTimeButton2WasOff = !joyButton(2);

                turbo = isShift || joyButton(0) || iskeydown(SDLK_x) || mouseRight;


                // TODO: FUNNIER MOUSE TURNS 
                if (true)
                {
                    // MOUSESENSITIVITY ;
                    angle += mouse.vx * dt * 10.0f * TURNSPEED * invMass();
                    mouse.vx = 0; // stops turning madness on start
                    
                }


                if (isLeft && (!isAlt))
                {
                    angle += dt * 60.0f * TURNSPEED * invMass();
                }

                if (isRight && (!isAlt))
                {
                    angle -= dt * 60.0f * TURNSPEED * invMass();
                }

                if (turbo || isUp)
                {
                    progress(velocity(), 0, dt);
                }

                if (isDown)
                {
                    progress(velocity(), PI, dt);
                }
                if (isLeft && isAlt) { progress(velocity(), + PI_2, dt); }
                if (isRight && isAlt) { progress(velocity(), - PI_2, dt); }


                angle -= axisx * dt * 60.0f * TURNSPEED * invMass();
                progress(-velocity() * axisy, 0, dt);
                break;
            }

            default: // IA
            {
                vec2f targetPos()
                {
                    if (player is null) return vec2f(0.0f);

                    float intelligence = std.algorithm.min(1.0f, level / 30.0f);

                    if (attitude == Attitude.KAMIKAZE)
                        return player.currentPosition + intelligence * player.mov * 60;

                    if (attitude == Attitude.AGGRESSIVE)
                    {
                        float speed = (mov * invMass).length;

                        float d = (currentPosition - player.currentPosition).length / (BULLET_BASE_SPEED + speed);
                        return player.currentPosition + intelligence * player.mov * d;
                    }
                    return player.currentPosition;
                }


                vec2f target = targetPos();
                float targetAngle = player is null ? angle + PI : player.angle;


                float dx = currentPosition.x - target.x;
                float dy = currentPosition.y - target.y;
                float d = vec2f(dx,dy).length;
                float a = atan2(dy, dx) + PI;

                float dangle = normalizeAngle(a - angle);
                float dpangle = normalizeAngle(a - targetAngle);
                if ((*_random).nextFloat < 0.6 * dt)
                    drag();

                switch(attitude)
                {
                    case Attitude.AGGRESSIVE:
                        {
                            if (abs(dangle) < 1.0f)
                            {
                                angle += dangle * TURNSPEED;
                                if ((d > 150) && ((*_random).nextFloat < 0.01f)) turbo = true;
                            }
                            else
                            {
                                angle += dangle * TURNSPEED * 0.5f;
                            }
                            progress(velocity() * (std.algorithm.min(0.4f, 1.0f -(abs(dangle) / PI))), 0, dt);
                            if (abs(dangle) < 0.2f)
                            {
                                shoot();
                            }
                            else if ((*_random).nextFloat < 0.6 * dt)
                            {
                                vangle += dangle * TURNSPEED * ((*_random).nextFloat + 0.5f);
                            }
                        }
                        break;

                    case Attitude.FEARFUL:
                        {
                            if ((*_random).nextFloat < 3 * dt) vangle = vangle - dangle * TURNSPEED* (*_random).nextFloat * 0.2;
                            progress(velocity(), 0, dt);
                            if ((*_random).nextFloat < 1.5 * dt) turbo = true;
                            if (abs(dangle) < 12 * dt) shoot();
                        }
                        break;

                    case Attitude.KAMIKAZE:
                        {
                            angle = angle + dangle * TURNSPEED * 1.8;
                            if (abs(dangle) < 0.1)
                            {
                                if ((*_random).nextFloat < 3 * dt) turbo = true;
                            }
                            float advance = clamp(1 - sqr(abs(dangle)/PI), 0.0f, 1.0f);
                            progress(velocity() * advance, 0, dt);
                        }
                        break;

                    case Attitude.OCCUPIED:
                    default:
                        {
                            vangle = vangle + (*_random).nextFloat2 * TURNSPEED * 0.012;
                            if ((*_random).nextFloat < 0.1f * dt) turbo = !turbo;
                            progress(velocity() * 0.5,0, dt);
                            if ((*_random).nextFloat < 0.6 * dt)
                                drag();
                        }
                        break;
                }
            }
        }
    }

    float velocity()
    {
        return baseVelocity * (1.0f + (shipSize - 7) * 0.07f);
    }

    void progress(float acceleration, float theta, float dt)
    {
        if (abs(acceleration) < 1e-2) return;
        float r = acceleration;// * Fclamp(s.life + half);

        if ((turbo) && (r > 0))
        {
            if (!buyWithEnergy(TURBO_COST * dt * 60.0f))
            {
                turbo = false;
            }
            else
            {
                r = r * TURBO_FACTOR;
            }
        }

        engineExcitation = std.algorithm.min(1.0f, engineExcitation + abs(r));

        vec2f thrust = polarOld(angle + theta, 1.0f) * r;

        vec2f dec = polarOld(angle, shipSize * 0.75f);

        mov += thrust * 60.0f * dt;

        int nParticul = cast(int)(0.4f + (1 + round(r * r * 2)) * PARTICUL_FACTOR * 70 * dt * (0.8f + 0.4f * (*_random).nextFloat) );
        uint pcolor = particleColor();
        vec2f basePos = currentPosition - dec;
        for (int i = 0; i < nParticul; ++i)
        {
            float where = (*_random).nextFloat - 0.5f;
            int life = cast(int)( 80 * ((*_random).nextFloat) ^^ 2);
            game.particles.add(basePos + where * mov, vec2f(0), angle + PI + theta, 0,
                               (*_random).nextAngle, (*_random).nextFloat, pcolor, life);

        }
    }

    void drag()
    {
        if (!isAlive()) return;
        float dmin = sqr(DRAG_DISTANCE);
        Powerup nearest = null;
        Player nearestPlayer = null;

        int count = 0;

        for (int i = 0; i < powerupIndex; ++i)
        {
            Powerup p = powerupPool[i];
            assert(!p.dead);

            if (p.getDragger() !is this)
            {
                float f = currentPosition.squaredDistanceTo(p.pos);
                if (f < dmin)
                {
                    dmin = f;
                    if ((p.getDragger() is null) || ( p.getDragger.currentPosition.squaredDistanceTo(p.pos) > f))
                    {
                        nearest = p;
                    }
                }
            }
        }

        // big ships, with life, with invincibility, want to drag you more
        float probOfCatching = 0.0025f * shipSize * life * (isInvincible() ? 3 : 1);

        void catchOtherPlayer(Player other)
        {
            if (other is null)
                return;
            if (!other.isAlive())
                return;
            if (_catchedPlayer !is null)
                return;
            if (other._catchedPlayer !is null)
                return;
            if (!isHuman && !other.isHuman)
                return;

            if (this !is other)
            {
                float dist2 = currentPosition.squaredDistanceTo(other.currentPosition);
                if (dist2 < dmin)
                {
                    dmin = dist2;
                    nearest = null;
                    nearestPlayer = other;
                }
            }
        }
        if (isHuman || ((*_random).nextFloat() < probOfCatching)) // AI rarely catch you
        {
            catchOtherPlayer(player);
            for (int i = 0; i < ia.length; ++i)
                catchOtherPlayer(ia[i]);
        }

        if (nearestPlayer !is null)
        {
            _catchedPlayer = nearestPlayer; // enforce distance between two players
            _catchedPlayer._catchedPlayer = this;
            _catchedPlayerDistance = _catchedPlayer.currentPosition.distanceTo(currentPosition);
            _catchedPlayer._catchedPlayerDistance = _catchedPlayerDistance;
            assert(isFinite(_catchedPlayerDistance));
            game.soundManager.playSound(_catchedPlayer.currentPosition, 0.7f + (*_random).nextFloat * 0.3f,
                                        SOUND.CATCH_POWERUP);
        }
        else if ((nearest !is null) && (_numDraggedPowerups < MAX_DRAGGED_POWERUPS))
        {
            nearest.setDragger(this);
        }
        else // nearest is null
        {
            if (isHuman)
            {
                game.soundManager.playSound(currentPosition, 0.25f + (*_random).nextFloat * 0.15f, SOUND.FAIL);
            }
        }
    }

    void rotatePush(float vangleAmount)
    {
        vangle += vangleAmount; 
        //if (isHuman) return; // no to dizzy!
        if (isHuman)
            game.camera().dizzy(10 * abs(vangleAmount));
    }

    static void computeCollision(SoundManager soundManager, Player p1, Player p2)
    {
        if (p1 is null) return;
        if (p2 is null) return;
        if (!p1.isAlive()) return;
        if (!p2.isAlive()) return;

        if (Player.collisioned(p1, p2))
        {
            if (p2.isInvincible && (!p1.isInvincible))
            {
                p1.damage(p1.damageToExplode());
            }
            else if ((!p2.isInvincible) && p1.isInvincible)
            {
                p2.damage(p2.damageToExplode());
            }
            else
            {
                float v1 = p1.mov.length;
                float v2 = p2.mov.length;
                float damage = p2.mov.distanceTo(p1.mov) * COLLISION_DAMAGE_FACTOR / (v1 + v2 + 0.01f);
                p1.damage(v2 * damage);
                p2.damage(v1 * damage);

                soundManager.playSound(p2.currentPosition, damage, SOUND.COLLISION);

                if ((p1.isAlive()) && (p2.isAlive()))
                {
                    if ((p1.isInvincible) && (p2.isInvincible))
                    {
                        p1.mov *= 2.0f;
                        p2.mov *= 2.0f;
                        p1.invincibility = 0.0f;
                        p2.invincibility = 0.0f;
                    }
                }
                else
                {
                    // weapon stealing
                    int weapon = std.algorithm.max(p1.weaponclass, p2.weaponclass);
                    p1.weaponclass = weapon;
                    p2.weaponclass = weapon;
                }

                p1.rotatePush(((*p1._random).nextFloat - 0.5) * damage * (p1.isHuman ? 0.07 : 0.1));
                p2.rotatePush(((*p2._random).nextFloat - 0.5) * damage * (p2.isHuman ? 0.07 : 0.1));
            }
        }
    }
}

__gshared Player[NUMBER_OF_IA] ia;

__gshared Player player;

void playerkillia()
{
    for (int i = 0; i < ia.length; ++i)
    {
        if (ia[i] !is null)
        {
            ia[i].damage(100.0f);
        }
    }
}


bool allEnemiesAreDead()
{
    for (int i = 0; i < NUMBER_OF_IA; ++i)
    {
        if (ia[i] !is null)
        {
            if (!ia[i].dead)
            {
                return false;
            }
        }
    }
    return true;
}
