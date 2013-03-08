module particles;


import globals, vga2d, utils, palettes, misc.logger, std.string, camera;
import math.all;
import game, map;

private struct Tparticul
{
    vec2f pos;
    vec2f mov;
    uint color;
    float life;
}

final class ParticleManager
{
    private
    {
        const MAX_PARTICUL = 50000;
        const ENOUGH_PARTICUL = MAX_PARTICUL >> 1;
        
        Tparticul[] particulstack;
        int particleIndex;
        Game game;
        Camera _camera;        
    }

    public
    {

        this(Game game, Camera camera)
        {
            particulstack.length = MAX_PARTICUL;
            particleIndex = 0;
            this.game = game;
            _camera = camera;
        }

        void add(vec2f pos, vec2f baseVel, float mainangle, float mainspeed, float angle, float speed, uint color, int life)
        {
            if (pos.squaredDistanceTo(_camera.position()) > OUT_OF_SIGHT) return;
            if (particleIndex >= MAX_PARTICUL) return;
            if ((particleIndex >= ENOUGH_PARTICUL) && (random.nextRange(2) == 0)) return;
            if (life < 0.0001f) return;

            Tparticul* n = &particulstack[particleIndex++];
            n.pos = pos;
            n.mov = polarOld(angle, speed) + polarOld(mainangle, mainspeed) + baseVel;

            n.color = rgba(Rvalue(color), Gvalue(color), Bvalue(color), Avalue(color) >> 4);
            n.life = life / 60.f;
        }

        void move(Map map, float dt) // also delete dead particles
        {
            int i = 0;
            const uint DECAY = 0x10000000;

            float dt2 = dt * 60.f;
            while (i < particleIndex)
            {
                with(particulstack[i])
                {
                    life -= dt;
                    if (life < 16 / 60.f) color = colorsub(color,DECAY);
                    pos += mov * dt2;

                    map.enforceBounds(pos, mov, 0.f, 0.35f, 0.f);
                }

                if (particulstack[i].life <= 0)
                {
                    --particleIndex;
                    particulstack[i] = particulstack[particleIndex];
                } else ++i;
            }
        }

        void draw()
        {
            GL.disable(GL.POINT_SMOOTH);
            GL.enable(GL.BLEND);

            GL.blend(GL.BlendMode.ADD, GL.BlendFactor.SRC_ALPHA, GL.BlendFactor.ONE_MINUS_SRC_ALPHA);
            
            {
                GL.pointSize(10.f);
                GL.begin(GL.POINTS);
                for (int i = 0; i < particleIndex; ++i)
                with(particulstack[i])
                {
                    uint colorswapped = swapRB(average(0,color));
                    GL.color(colorswapped);
                    GL.vertex(pos);
                }
                GL.end();

                GL.pointSize(5.f);
                GL.begin(GL.POINTS);
                for (int i = 0; i < particleIndex; ++i)
                with(particulstack[i])
                {
                    if (life > 0.4f)
                    {
                        uint colorswapped = swapRB(color);
                        GL.color(colorswapped);
                        GL.vertex(pos);
                    }
                }
                GL.end();

                GL.pointSize(2.f);
                GL.begin(GL.POINTS);
                for (int i = 0; i < particleIndex; ++i)
                with(particulstack[i])
                {
                    if (life > 0.8f && (i & 1))
                    {
                        uint colorswapped = swapRB(average(clwhite,color));
                        GL.color(colorswapped);
                        GL.vertex(pos);
                    }
                }
                GL.end();
            }

            GL.disable(GL.BLEND);
        }
    }
}
