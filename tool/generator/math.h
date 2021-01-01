#pragma once

#include <math.h>

template <typename T>
T min(T a, T b) { return (a <= b) ? a : b; }

template <typename T>
T max(T a, T b) { return (a >= b) ? a : b; }

template <typename T>
T abs(T a) { return (a < 0) ? -a : a; }

#define DEG_TO_RAD(x) ((x)*M_PI/180.0f)

#define M_PI 3.1415926535897932384626433832795f

class Vec2
{
public:
    Vec2() = default;
    Vec2(float x, float y) : mX(x), mY(y) {}

    float Length() const
    {
        return sqrtf(mX*mX + mY * mY);
    }

    Vec2 Normalized() const
    {
        float len = Length();
        return (len > 0.0f) ? Vec2(mX / len, mY / len) : Vec2(0.0f, 0.0f);
    }

    float mX, mY;
};

class Vec3
{
public:
    Vec3() = default;
    Vec3(float x, float y, float z) : mX(x), mY(y), mZ(z) {}
    Vec3(const Vec2& v, float z) : mX(v.mX), mY(v.mY), mZ(z) {}

    Vec2 XY() const
    {
        return Vec2(mX, mY);
    }

    Vec3 operator *(float scalar) const
    {
        return Vec3(mX*scalar, mY*scalar, mZ*scalar);
    }

    Vec3 operator +(const Vec3& other) const
    {
        return Vec3(mX + other.mX, mY + other.mY, mZ + other.mZ);
    }

    Vec3& operator +=(const Vec3& other)
    {
        mX += other.mX;
        mY += other.mY;
        mZ += other.mZ;
        return *this;
    }

    float mX, mY, mZ;
};


