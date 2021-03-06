module palettes;

import std.math;
import gfm.math;
import utils;

struct Tbgra
{
    align(1)
    {
        ubyte b, g, r, a;
    }
}

struct Trgb
{
    align(1)
    {
        ubyte r, g, b;
    }
}

struct Trgba
{
    align(1)
    {
        ubyte r, g, b, a;
    }
}

// color constants

const clblack = 0xFF000000;
const clwhite = 0xFFFFFFFF;
const clred = 0xFFFF0000;
const clgreen = 0xFF00FF00;
const clblue = 0xFF0000FF;
const clyellow = 0xFFFFFF00;
const clgrey = 0xFF808080;
const clmagenta = 0xFFFF00FF;

int Avalue(uint c)
{
    return (0xff & (c >> 24));
}

int Rvalue(uint c)
{
    return (0xff & (c >> 16));
}

int Gvalue(uint c)
{
    return (0xff & (c >> 8));
}

int Bvalue(uint c)
{
    return (0xff & c);
}
/*
uint Approach(uint c, uint target)
{
    int r = Rvalue(c);
    int g = Gvalue(c);
    int b = Bvalue(c);
    return rgb(r + sign(Rvalue(target)-r),
               g + sign(Gvalue(target)-g),
               b + sign(Bvalue(target)-b));
}
*/

uint Average(uint c1, uint c2)
{
    int r1 = Rvalue(c1);
    int g1 = Gvalue(c1);
    int b1 = Bvalue(c1);
    int a1 = Avalue(c1);
    int r2 = Rvalue(c2);
    int g2 = Gvalue(c2);
    int b2 = Bvalue(c2);
    int a2 = Avalue(c2);



    return rgba((r1 + r2) >> 1,
                (g1 + g2) >> 1,
                (b1 + b2) >> 1,
                (a1 + a2) >> 1);
}

alias Average average;

uint ColorAdd(uint c1, uint c2)
{
    
    int r = Rvalue(c1) + Rvalue(c2);
    int g = Gvalue(c1) + Gvalue(c2);
    int b = Bvalue(c1) + Bvalue(c2);
    int a = Avalue(c1) + Avalue(c2);

    if (r > 255) r = 255;
    if (g > 255) g = 255;
    if (b > 255) b = 255;
    if (a > 255) a = 255;

    return rgba(r,g,b,a);    
}

alias ColorAdd coloradd;

uint ColorSub(uint c1, uint c2)
{
    
    int r = Rvalue(c1) - Rvalue(c2);
    int g = Gvalue(c1) - Gvalue(c2);
    int b = Bvalue(c1) - Bvalue(c2);
    int a = Avalue(c1) - Avalue(c2);

    if (r < 0) r = 0;
    if (g < 0) g = 0;
    if (b < 0) b = 0;
    if (a < 0) a = 0;

    return rgba(r,g,b,a);
}

alias ColorSub colorsub;

uint ColorROL(uint c, byte bits)
{
    bits = bits & 31;
    return (c << bits) | (c >> (32 - bits));
}

uint ColorROR(uint c, byte bits)
{
    bits = bits & 31;
    return (c >> bits) | (c << (32 - bits));
}

uint MixColor(uint c1, uint c2, int t)
{
    int r1 = Rvalue(c1);
    int g1 = Gvalue(c1);
    int b1 = Bvalue(c1);
    int a1 = Avalue(c1);
    int r2 = Rvalue(c2);
    int g2 = Gvalue(c2);
    int b2 = Bvalue(c2);
    int a2 = Avalue(c2);

    int t2 = 255 - t;

    return rgba((r1 * t2 + r2 * t) >> 8,
               (g1 * t2 + g2 * t) >> 8,
               (b1 * t2 + b2 * t) >> 8,
               (a1 * t2 + a2 * t) >> 8);
}
alias MixColor mixcolor;

uint rgb(int r, int g, int b)
{
    return 0xff000000 | (r << 16) | (g << 8) | b;
}

uint swapRB(uint color)
{
    int r = Rvalue(color);
    int g = Gvalue(color);
    int b = Bvalue(color);
    int a = Avalue(color);
    return rgba(cast(ubyte)b, cast(ubyte)g, cast(ubyte)r, cast(ubyte)a);
}

uint rgba(int r, int g, int b, int a)
{
    return (a << 24) | (r << 16) | (g << 8) | b;
}


uint Frgb(float r, float g, float b)
{
    return rgb(cast(int)round(clamp(r, 0.0f, 1.0f)*255.0f), 
               cast(int)round(clamp(g, 0.0f, 1.0f)*255.0f), 
               cast(int)round(clamp(b, 0.0f, 1.0f)*255.0f));
}

uint Frgb(vec3f c)
{
    return Frgb(c.x, c.y, c.z);
}


uint Frgba(float r, float g, float b, float a)
{
    return rgba(cast(int)round(clamp(r, 0.0f, 1.0f)*255.0f), 
                cast(int)round(clamp(g, 0.0f, 1.0f)*255.0f), 
                cast(int)round(clamp(b, 0.0f, 1.0f)*255.0f), 
                cast(int)round(clamp(a, 0.0f, 1.0f)*255.0f));
}

uint Frgba(vec4f c)
{
    return Frgba(c.x, c.y, c.z, c.w);
}

vec4f RGBAF(uint c)
{
    return vec4f(Rvalue(c), Gvalue(c), Bvalue(c), Avalue(c)) / 255.0f;
}

vec3f RGBF(uint c)
{
    return vec3f(Rvalue(c), Gvalue(c), Bvalue(c)) / 255.0f;
}
