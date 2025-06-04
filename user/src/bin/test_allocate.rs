#![no_std]
#![no_main]
extern crate alloc;

use alloc::vec;
use user_lib::{print, println};

#[unsafe(no_mangle)]
pub fn main(argc: usize, mut argv: &[&str]) -> i32 {
    let proc = argv[0];
    if argc != 3 {
        argv = &["", "40", "40"]; // it will drop the first argument
    }
    let mut array = vec![vec![0; argv[1].parse().unwrap()]; argv[2].parse().unwrap()];
    for i in 0..array.len() {
        for j in 0..array[i].len() {
            print!("{} ", array[i][j]);
        }
        println!();
    }
    0
}
