module utils;

import math.all;

__gshared Random random;

shared static this()
{
    random = Random();
}

float normalizeAngle(float angle)
{
    double PI2 = 6.283185307179586476925286766559;

    while(angle > PI)
        angle -= PI2;

    while(angle < -PI)
        angle += PI2;

    return angle;
}

void keepAtLeastThatSize(T)(ref T[] slice)
{
    auto capacity = slice.capacity;
    auto length = slice.length;
    if (capacity < length)
        slice.reserve(length); // should not reallocate
}


// polar
vec2!(T) polarOld(T)(T angle, T radius)
{
    T s = void, c = void;
    sincos(angle, s, c);
    return vec2!(T)(c * radius, s * radius);
}
