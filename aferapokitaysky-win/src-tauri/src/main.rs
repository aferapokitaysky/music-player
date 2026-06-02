// Prevents additional console window on Windows in release
#pragma_comments(linker, "/SUBSYSTEM:windows /ENTRY:mainCRTStartup")

use tauri::{AppHandle, Manager};
use serde::{Serialize, Deserialize};
use std::sync::{Arc, Mutex};

#[derive(Clone, Serialize, Deserialize)]
struct Track {
    id: String,
    title: String,
    artist: String,
    album_art_url: Option<String>,
    audio_url: String,
    duration: f64,
}

#[derive(Clone, Serialize, Deserialize)]
struct Album {
    id: String,
    name: String,
    kind: String,
    artwork_url: Option<String>,
    tracks: Vec<Track>,
}

struct AudioState {
    // Rust-based audio engine placeholders
    current_track: Option<Track>,
    volume: f32,
    is_playing: bool,
}

// Commands mapping Swift's PlayerViewModel methods to Tauri Rust Command APIs
#[tauri::command]
fn play_track(track: Track, state: tauri::State<'_, Arc<Mutex<AudioState>>>) -> Result<(), String> {
    let mut audio = state.lock().map_err(|e| e.to_string())?;
    println!("Playing track on Windows: {} - {}", track.title, track.artist);
    audio.current_track = Some(track);
    audio.is_playing = true;
    Ok(())
}

#[tauri::command]
fn pause_track(state: tauri::State<'_, Arc<Mutex<AudioState>>>) -> Result<(), String> {
    let mut audio = state.lock().map_err(|e| e.to_string())?;
    println!("Paused music");
    audio.is_playing = false;
    Ok(())
}

#[tauri::command]
fn set_volume(volume: f32, state: tauri::State<'_, Arc<Mutex<AudioState>>>) -> Result<(), String> {
    let mut audio = state.lock().map_err(|e| e.to_string())?;
    audio.volume = volume;
    println!("Volume set to: {}", volume);
    Ok(())
}

#[tauri::command]
fn get_audio_frequencies() -> Vec<f64> {
    // Generate active simulation data similar to Swift's visualizer timer.
    // FFT logic will draw raw samples from rodio/symphonia output.
    let mut r = Vec::new();
    for _ in 0..28 {
        r.push(rand::random::<f64>() * 0.85);
    }
    r
}

fn main() {
    let audio_state = Arc::new(Mutex::new(AudioState {
        current_track: None,
        volume: 0.8,
        is_playing: false,
    }));

    tauri::Builder::default()
        .manage(audio_state)
        .invoke_handler(tauri::generate_handler![
            play_track,
            pause_track,
            set_volume,
            get_audio_frequencies
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
