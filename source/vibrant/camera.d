module camera;

import utils;

import std.math;
import gfm.math;

final class Camera
{
    public
    {
        this()
        {
            _position = vec2f(0.0f);
            _angle = -3.1415926535 * 0.5f;
            _lastPosition = _position;
            _lastAngle = _angle;

            _targetPosition = _position;
            _targetAngle = _angle;
            _camDizzy = 0.0f;
        }

        void dizzy(float seconds)
        {
            _camDizzy = std.algorithm.min(1.0f, std.algorithm.max(_camDizzy, seconds));
        }

        void nodizzy()
        {
            _camDizzy = 0;
        }

        vec2f position()
        {
            return _position;
        }

        float angle()
        {
            return _angle;
        }

        void setTarget(vec2f targetPos, float targetAngle)
        {
            _targetPosition = targetPos;
            _targetAngle = targetAngle;
        }

        void progress(float dt, bool isRotateViewNow)
        {
            double truc = 1.0 - exp(dt * 3.28 * log(CAMERA_VELOCITY));
            double trucAngle = truc * std.algorithm.max(0.0f, 1.0f - _camDizzy);
            _lastAngle = _angle;
            _lastPosition = _position;
                // standart camera:
            //_angle = _angle + normalizeAngle(_targetAngle - _angle) * trucAngle * (isRotateViewNow ? 0.4 : 1.0f);
                // test:
            //_angle = _angle + normalizeAngle(_targetAngle - _angle) * trucAngle * 0.5f ;
                // Good steady camera:
            _angle = _targetAngle;
            _position += (_targetPosition - _position) * truc;

            _camDizzy = std.algorithm.max(0.0f, _camDizzy - dt);
        }

        bool canSee(vec2f position)
        {            
            return _position.squaredDistanceTo(position) < OUT_OF_SIGHT * OUT_OF_SIGHT;
        }
    }

    private
    {
        enum CAMERA_VELOCITY = 0.12;
        enum OUT_OF_SIGHT = 1000.0f;

        vec2f _position;
        float _angle;

        vec2f _lastPosition;
        float _lastAngle;

        vec2f _targetPosition;
        float _targetAngle;

        float _camDizzy;
    }
}