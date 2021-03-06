module vibrantprogram;

import std.path;
import std.math;
import gfm.math;
import sdl.all;
import misc.all;
import gl.all;
import globals;
import utils;
import game;
import mousex;
import joy;
import derelict.util.exception;

final class VibrantProgram : SDLApp
{
    private
    {
        Image m_buffer;
        Game m_game;
        box2i m_view;

        string cheatString;
        Texture2D m_blurTex;
        MouseState _mouse;

    //    double mA1, mA2;

        bool m_doRender = true;
    }

    public
    {
        this(string basePath, int asked_width, int asked_height, double ratio, bool fullscreen, int fsaa, bool playMusic, float gamma, bool vsync, bool doBlur)
        {
            FSAA aa = void;
            if (fsaa == 2) aa = FSAA.FSAA2X;
            else if (fsaa == 4) aa = FSAA.FSAA4X;
            else if (fsaa == 8) aa = FSAA.FSAA8X;
            else if (fsaa == 16) aa = FSAA.FSAA16X;
            else aa = FSAA.OFF;

            super(asked_width, asked_height, fullscreen, false, "Vibrant", buildPath(basePath, "data/icon.bmp"), aa, 0, OpenGLVersion.Version20, true);

            bool doPostProcessing = true;

     /*       try
            {
                // try to load OpenGL 2.0
                DerelictGL.load();
                doPostProcessing = true;
            }
            catch(DerelictException e)
            {
                // fallback to ugly mode
                doPostProcessing = false;
            }*/

            version(linux)
            {
                doPostProcessing = false;
            }


            GL.check();

            SDL_ShowCursor(SDL_DISABLE);

            if (abs(ratio) < 0.0001) // auto ratio
            {
                ratio = cast(double)width / height;
                if (ratio < 5.0 / 4.0) ratio = 5.0 / 4.0;
                if (ratio > 16.0 / 9.0) ratio = 16.0 / 9.0;
            }

            int yOffset = 0;
            version(OSX)
            {
                yOffset += 50;
            }

            // adjust viewport according to ratio
            m_view = box2i(0, yOffset, width, height - yOffset).subRectWithRatio(ratio);
            GL.check();
            GL.disable(GL.DEPTH_TEST);
            GL.disable(GL.BLEND, GL.FOG, GL.LIGHTING, GL.NORMALIZE, GL.STENCIL_TEST, GL.CULL_FACE);
            GL.disable(GL.AUTO_NORMAL, GL.DITHER, GL.FOG, GL.LIGHTING, GL.NORMALIZE);
            GL.disable(GL.POLYGON_SMOOTH, GL.LINE_SMOOTH, GL.POINT_SMOOTH);
            GL.clearColor = vec4f(0, 0, 0, 1);
            GL.alphaFunc(GL.GREATER, 0.001f);
            GL.hint(GL.POINT_SMOOTH_HINT, GL.NICEST);

            m_game = new Game(basePath, m_view, doPostProcessing);

            cheatString = "";
        }

        void close()
        {
            m_game.close();
        }

        override void onRender(double elapsedTime)
        {
            if (m_doRender)
            {
                GL.clear(true, true, true);

                m_game.draw();
            }
        }

        override void onMove(double elapsedTime, double dt)
        {
            if (m_game.isPaused())
                return;

            // restart a game
            {
                bool mouseLeft = 0 != (_mouse.buttons & MOUSE_LEFT);
                bool isFire = iskeydown(SDLK_LCTRL) || iskeydown(SDLK_RCTRL) || iskeydown(SDLK_c) || mouseLeft || joyButton(1);

                if (isFire)
                {
                    m_game.newGame();
                }
            }

            dt *= 75.0 / 60.0;
            debug
            {
                if (iskeydown(SDLK_PAGEDOWN))
                    m_game.addZoomFactor(1.2f * dt);

                if (iskeydown(SDLK_PAGEUP))
                    m_game.addZoomFactor(- 1.2f * dt);
            }
            m_game.progress(_mouse, dt);
        }

        override void onKeyUp(int key, int mod)
        {
            if (key == SDLK_ESCAPE) terminate();

            if (key == SDLK_DELETE)
            {
                m_game.suicide();
            }
        }

        override void onFrameRateChanged(float frameRate)
        {
        }

        override void onCharDown(dchar ch)
        {
            m_game.charTyped(ch);
        }

        override void onKeyDown(int key, int mod)
        {

            debug
            {
                if (key == SDLK_F1)
                {
                    m_doRender = !m_doRender;
                }
            }
        }

        override void onMouseMove(int x, int y, int dx, int dy)
        {
            //_mouse.x = x; 
            _mouse.x = width/2; // capture at center mouse anytime
            //_mouse.y = y;
            _mouse.y = height/2;
            _mouse.vx = dx;
            _mouse.vy = dx;
        }

        override void onMouseDown(int button)
        {
            if (button == SDL_BUTTON_LEFT)
                _mouse.buttons |= MOUSE_LEFT;

            if (button == SDL_BUTTON_MIDDLE)
                _mouse.buttons |= MOUSE_CENTER;

            if (button == SDL_BUTTON_RIGHT)
                _mouse.buttons |= MOUSE_RIGHT;

            /*if (button == SDL_BUTTON_WHEELUP)
                _mouse.buttons |= MOUSE_CENTER;    // hack to catch powerups with mousewheel

            if (button == SDL_BUTTON_WHEELDOWN)
                _mouse.buttons |= MOUSE_CENTER;    // hack to catch powerups with mousewheel*/
        }

        override void onMouseUp(int button)
        {
            if (button == SDL_BUTTON_LEFT)
                _mouse.buttons &= ~MOUSE_LEFT;

            if (button == SDL_BUTTON_MIDDLE)
                _mouse.buttons &= ~MOUSE_CENTER;

            if (button == SDL_BUTTON_RIGHT)
                _mouse.buttons &= ~MOUSE_RIGHT;
        }

        override void onReshape(int width, int height)  {  }

        // GAME LOOP
        void run()
        {
            m_frameCounter.reset();

            bool firstFrame = true;

            while (! m_finished)
            {
                firstFrame = false;

                double time = m_frameCounter.elapsedTime;

                double dt = m_frameCounter.deltaTime;
                processEvents();
                onMove(time, dt);

                if (!firstFrame) swapBuffers();

                firstFrame = false;

                if (m_frameCounter.tick())
                {
                    onFrameRateChanged(m_frameCounter.frameRate);
                }
                onRender(time);
                //std.gc.fullCollect();
                //std.gc.minimize();
            }

            // flush pending events
            processEvents();
        }
    }
}



