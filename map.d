module map;

import math.all;
import camera, palettes;
import vga2d;
import utils;

const TILE_SIZE = 200.0f;
const TILE_OUTSIDE = 0;
const TILE_NORMAL = 1;

const LINE_ELECTRIC_ARC = 0;
const LINE_TILE_SEP = 1;

struct MapLine
{
    vec2f a;
    vec2f b;
    int type;
}

class MapTile
{
    public
    {
        this(int type, vec2i index)
        {
            _type = type;
            _index = index;
        }

        int type()
        {
            return _type;
        }

        vec2f pos()
        {
            return vec2f((_index.x - 16) * TILE_SIZE, (_index.y - 16) * TILE_SIZE);
        }

        box2f bounds()
        {
            vec2f p = pos();
            return box2f(p, p + vec2f(TILE_SIZE, TILE_SIZE));
        }

        
    }

    private
    {
        int _type;
        vec2i _index;
    }
}

class Map
{
    public
    {
        MapLine[] _outLines;

        this()
        {
            random = Random();
            _tiles.length = 32 * 32;
            for (int i = 0; i < 32; ++i)
                for (int j = 0; j < 32; ++j)
                {
                    bool border = i == 0 || j == 0 || i == 31 || j == 31;
                    _tiles[j * 32 + i] = new MapTile(border ? TILE_OUTSIDE : TILE_NORMAL, vec2i(i, j));
                }
        }

        static bool indexInMap(vec2i i)
        {
            return i.x >= 0 && i.x < 32 && i.y >= 0 && i.y < 32;
        }

        static vec2i getIndex(vec2f pos)
        {
            return vec2i (floor(pos.x / TILE_SIZE) + 16, floor(pos.y / TILE_SIZE) + 16);
        }

        MapTile getTile(vec2i i)
        {
            assert(indexInMap(i));
            return _tiles[i.y * 32 + i.x];
        }

        MapTile getTile(int ix, int iy)
        {
            assert(indexInMap(vec2i(ix, iy)));
            return _tiles[iy * 32 + ix];
        }

        MapTile getTileAtPoint(vec2f pos)
        {
            vec2i i = getIndex(pos);            
            return getTile(i);
        }

        // returns a random point in the map
        vec2f randomPoint()
        {
            // choose a tile at random
            MapTile t;

            do
            {
                t = getTile(random.nextRange(32), random.nextRange(32));
            }
            while (t.type() != TILE_NORMAL);

            // chose a random position on this tile
            box2f b = t.bounds();
            return vec2f( b.xmin + b.width * random.nextFloat(), b.ymin + b.height * random.nextFloat());
        }

        // get 9 neighbours
        void getNeighbourTiles(vec2f pos, MapTile[] outputTiles)
        {
            vec2i i = getIndex(pos);
            assert(indexInMap(i));

            for (int y = 0; y < 3; ++y)
                for (int x = 0; x < 3; ++x)                
                    outputTiles[y * 3 + x] = getTile(vec2i (i.x + x - 1, i.y + y - 1));
        }

        // doesn't need to be precise above 100
        float distanceToBorder(vec2f pos)
        {
            MapTile[9] neighbours;
            getNeighbourTiles(pos, neighbours[]);

            float minDist = 100;

            for (int i = 0; i < 9; ++i)
            {
                if (neighbours[i].type() == TILE_OUTSIDE)
                {
                    float dist = neighbours[i].bounds().distanceTo(pos);
                    if (dist < minDist)
                        minDist = dist;
                }
            }
            return minDist;
        }

        // ensure an object is inside bounds
        void enforceBounds(ref vec2f pos, float radius)
        {
            float m = SIZE_OF_MAP - radius;
            if (m < 0.f) m = 0.f;
            int res = 0;
            if (pos.x < -m)
            {
                pos.x = -m;
                res = 0;
            }
            else if (pos.x > m)
            {
                pos.x = m;
                res = 0;
            }
            if (pos.y < -m)
            {
                pos.y = -m;
                res = 0;
            }
            else if (pos.y > m)
            {
                pos.y = m;
                res = 0;
            }
        }

        // ensure an object is inside bounds
        // and make it bounce
        int enforceBounds(ref vec2f pos, ref vec2f mov, float radius, float bounce, float constantBounce)
        {
            float m = SIZE_OF_MAP - radius;
            if (m < 0.f) m = 0.f;

            int res = 0;
            if (pos.x < -m)
            {
                pos.x = -m;
                mov.x = -mov.x * bounce + constantBounce;
                res++;
            }
            else if (pos.x > m)
            {
                pos.x = m;
                mov.x = -mov.x * bounce - constantBounce;
                res++;
            }
            if (pos.y < -m)
            {
                pos.y = -m;
                mov.y = -mov.y * bounce + constantBounce;
                res++;
            }
            else if (pos.y > m)
            {
                pos.y = m;
                mov.y = -mov.y * bounce - constantBounce;
                res++;
            }
            return res;
        }

        // ensure an object is inside bounds
        // and make it bounce, and turn its angle
        int enforceBounds(ref vec2f pos, ref vec2f mov, ref float angle,
                          float radius, float bounce, float constantBounce)
        {
            float m = SIZE_OF_MAP - radius;
            if (m < 0.f) m = 0.f;

            int res = 0;

            if (pos.x < -m)
            {
                pos.x = -m;
                mov.x = - mov.x * bounce + constantBounce;
                res++;
                if (abs(angle)> PI_2_F) angle = PI_F - angle;
            }
            else if (pos.x > m)
            {
                pos.x = m;
                mov.x = - mov.x * bounce - constantBounce;
                res++;
                if (abs(angle)< PI_2_F) angle = PI_F - angle;
            }

            if (pos.y < -m)
            {
                pos.y = -m;
                mov.y = -mov.y*bounce + constantBounce;
                res++;
                if (angle < 0.0 ) angle = TAU_F - angle;

            }
            else if (pos.y > m)
            {
                pos.y = m;
                mov.y = -mov.y*bounce - constantBounce;
                res++;
                if (angle > 0.0) angle = TAU_F - angle;
            }

            return res;
        }

        void generateMapLines(inout MapLine[] outLines)
        {
            int nline = 0;            

            for (int j = 0; j < 31; ++j)
                for (int i = 0; i < 31; ++i)
                {
                    MapTile here = getTile(vec2i(i, j));

                    box2f bounds = here.bounds();

                    vec2f a = bounds.a();
                    vec2f b = bounds.b();
                    vec2f c = vec2f(bounds.xmin, bounds.ymax);
                    vec2f d = vec2f(bounds.xmax, bounds.ymin);

                    MapTile down = getTile(i, j + 1);
                    MapTile right = getTile(i + 1, j);      

                    void push(vec2f p1, vec2f p2, MapTile t1, MapTile t2)
                    {
                        int lineType;
                        if (t1.type() != t2.type())
                            lineType = LINE_ELECTRIC_ARC;
                        else if (t1.type() == TILE_NORMAL && t2.type() == TILE_NORMAL)
                            lineType = LINE_TILE_SEP;
                        else
                            return;

                        if (outLines.length <= nline)
                            outLines.length = (outLines.length * 2 + 1);

                        outLines[nline++] = MapLine(p1, p2, lineType);
                    }

                    push(b, d, here, right);
                    push(c, b, here, down);
                }

        }

        void draw(Camera camera)
        {
            void eclairs(vec2f a, vec2f b)
            {
                float d = a.distanceTo(b);
                float t = 0;

                GL.begin(GL.LINE_STRIP);

                vertexf(a);
                while (t < 1.f)
                {
                    vec2f pt = t * b + (1 - t) * a;
                    vec2f p = pt + vec2f(random.nextFloat2 * random.nextFloat2 , random.nextFloat2 * random.nextFloat2) * 5.f;

                    vertexf(p);

                    t = t + 5.f / d;
                }
                vertexf(b);
                GL.end();
            }

            generateMapLines(_outLines);

            GL.lineWidth(3);
            GL.begin(GL.LINES);
            GL.color = 0.40f * vec3f(0.13,0.13,0.25);

            for (size_t i = 0; i < _outLines.length; ++i)
                with (_outLines[i])
                {
                    if (type == LINE_TILE_SEP)
                    {
                        if (camera.canSee(a) || camera.canSee(b))
                        {
                            GL.vertex(a);
                            GL.vertex(b);
                        }
                    }
                }

            GL.end();

            GL.color = RGBAF(0xff4040c0);

            for (size_t i = 0; i < _outLines.length; ++i)
                with (_outLines[i])
                {
                    if (type == LINE_ELECTRIC_ARC)
                    {
                        if (camera.canSee(a) || camera.canSee(b))
                        {
                            eclairs(a, b);
                        }
                    }
                }
        }
    }

    private
    {
        const float SIZE_OF_MAP = 3000;
        Random random;
        MapTile[] _tiles;        
    }
}

