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
            GL.enable(GL.BLEND);

            GL.blend(GL.BlendMode.ADD, GL.BlendFactor.SRC_ALPHA, GL.BlendFactor.ONE_MINUS_SRC_ALPHA);

            version(useVBO)
            {
                m_vbo1.clear();
                m_vbo2.clear();
                m_vbo3.clear();

                static vec4f colorToVec4(uint c)
                {
                    return vec4f(Rvalue(c), Gvalue(c), Bvalue(c), Avalue(c)) / 255.f;
                }

                for (int i = 0; i < particleIndex; ++i)
                with(particulstack[i])
                {
                    uint colorswapped1 = average(0,color);
                    uint colorswapped2 = color;
                    uint colorswapped3 = average(clwhite,color);
                    vec4f c1 = colorToVec4(colorswapped1);
                    vec4f c2 = colorToVec4(colorswapped2);
                    vec4f c3 = colorToVec4(colorswapped3);

                    m_vbo1.add(ParticleVertex(pos, c1));
                    m_vbo2.add(ParticleVertex(pos, c2));
                    m_vbo3.add(ParticleVertex(pos, c3));
                }
                m_vbo1.update;
                m_vbo2.update;
                m_vbo3.update;

                GL.pointSize(10.f);
                m_vbo1.draw(GL.POINTS, 0, m_vbo1.length);

                GL.pointSize(5.f);
                m_vbo2.draw(GL.POINTS, 1, m_vbo2.length);

                GL.pointSize(2.f);
                m_vbo3.draw(GL.POINTS, 2, m_vbo3.length);

            } else
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
