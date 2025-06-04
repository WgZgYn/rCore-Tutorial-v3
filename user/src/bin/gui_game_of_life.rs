#![no_std]
#![no_main]
extern crate alloc;

use alloc::vec;
use alloc::vec::Vec;
use embedded_graphics::pixelcolor::Rgb888;
use embedded_graphics::prelude::*;
use embedded_graphics::primitives::{PrimitiveStyle, Rectangle};
use user_lib::console::getchar;
use user_lib::{Display, VIRTGPU_XRES, VIRTGPU_YRES, get_time, key_pressed, sleep};

#[derive(Debug, Copy, Clone, Eq, PartialEq)]
enum State {
    Alive,
    Died,
}

struct GameOfLife<const WIDTH: usize, const HEIGHT: usize> {
    board: Vec<Vec<State>>,
    temp: Vec<Vec<State>>,
}

impl<const WIDTH: usize, const HEIGHT: usize> GameOfLife<WIDTH, HEIGHT> {
    fn new(alive_rate_percentage: u32) -> Self {
        assert!(alive_rate_percentage <= 100);
        let mut board = vec![vec![State::Died; WIDTH]; HEIGHT];
        let mut r = oorandom::Rand32::new(get_time() as u64);
        for i in 0..HEIGHT {
            for j in 0..WIDTH {
                if r.rand_u32() % 100 <= alive_rate_percentage {
                    board[i][j] = State::Alive;
                } else {
                    board[i][j] = State::Died;
                }
            }
        }
        Self {
            board,
            temp: vec![vec![State::Died; WIDTH]; HEIGHT],
        }
    }
    fn update(&mut self) {
        for i in 0..HEIGHT {
            for j in 0..WIDTH {
                let mut live = 0;

                // 修正边界检查
                let start_row = if i > 0 { i - 1 } else { 0 };
                let end_row = if i < HEIGHT - 1 { i + 1 } else { HEIGHT - 1 };
                let start_col = if j > 0 { j - 1 } else { 0 };
                let end_col = if j < WIDTH - 1 { j + 1 } else { WIDTH - 1 };

                for r in start_row..=end_row {
                    for c in start_col..=end_col {
                        if (r != i || c != j) && self.board[r][c] == State::Alive {
                            live += 1;
                        }
                    }
                }

                self.temp[i][j] = match (self.board[i][j], live) {
                    (State::Alive, 2) | (State::Alive, 3) => State::Alive,
                    (State::Died, 3) => State::Alive,
                    _ => State::Died,
                };
            }
        }
        for i in 0..HEIGHT {
            for j in 0..WIDTH {
                self.board[i][j] = self.temp[i][j];
            }
        }
    }
    fn draw(&self, disp: &mut Display) {
        for (i, row) in self.board.iter().enumerate() {
            for (j, status) in row.iter().enumerate() {
                let x = (j as i32) * PIXEL_SIZE as i32;
                let y = (i as i32) * PIXEL_SIZE as i32;
                // 确保坐标在显示范围内
                let color = if *status == State::Alive {
                    WHITE
                } else {
                    BLACK
                };
                Rectangle::new(Point::new(x, y), Size::new(PIXEL_SIZE, PIXEL_SIZE))
                    .into_styled(PrimitiveStyle::with_fill(color))
                    .draw(disp)
                    .unwrap();
            }
        }
        for i in 0..WIDTH as i32 * PIXEL_SIZE as i32 {
            Pixel(Point::new(i, 0), Rgb888::RED).draw(disp).unwrap();
            Pixel(
                Point::new(i, HEIGHT as i32 * PIXEL_SIZE as i32),
                Rgb888::RED,
            )
            .draw(disp)
            .unwrap();
        }
        for i in 0..HEIGHT as i32 * PIXEL_SIZE as i32 {
            Pixel(Point::new(0, i), Rgb888::RED).draw(disp).unwrap();
            Pixel(Point::new(WIDTH as i32 * PIXEL_SIZE as i32, i), Rgb888::RED)
                .draw(disp)
                .unwrap();
        }
    }
}

const PIXEL_SIZE: u32 = 8;
const WIDTH: usize = 80;
const HEIGHT: usize = 80;
const WHITE: Rgb888 = Rgb888::WHITE;
const BLACK: Rgb888 = Rgb888::BLACK;
const LF: u8 = 0x0au8;
const CR: u8 = 0x0du8;

#[unsafe(no_mangle)]
pub fn main() -> i32 {
    let mut disp = Display::new(Size::new(VIRTGPU_XRES, VIRTGPU_YRES));
    let mut game = GameOfLife::<WIDTH, HEIGHT>::new(60);
    let _ = disp.clear(BLACK).unwrap();
    let mut stop = false;
    loop {
        let _ = disp.clear(BLACK).unwrap();
        if key_pressed() {
            let c = getchar();
            match c {
                b' ' => stop = !stop,
                b'q' | LF | CR => break 0,
                _ => (),
            }
        }
        if !stop {
            game.update();
        }
        game.draw(&mut disp);
        Pixel(Point::new(0, 0), Rgb888::RED)
            .draw(&mut disp)
            .unwrap();
        disp.flush();
        sleep(100);
    }
}
