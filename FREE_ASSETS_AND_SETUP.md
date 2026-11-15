# RE:BOUND — Chapter 3

This project uses only original user-uploaded art and Godot's free built-in 3D geometry. No paid assets, external dependencies, or subscriptions are required.

## Optional CC0 assets (free)
- Kenney Platformer Kit: https://kenney.nl/assets/platformer-kit (CC0)
- Quaternius Ultimate Platformer: https://quaternius.itch.io/ultimate-platformer-pack (CC0; select free download)

You can replace the generated platform meshes with glTF/GLB models from these packs after the game works. Keep collision shapes in place.

## Setup
1. Extract ZIP into a NEW folder; keep your original project as backup.
2. Open project.godot with Godot 4.
3. Run with F5. Pong and Breakout are unchanged, except the chapter list now includes Chapter 3.
4. To test Chapter 3 directly, open chapter3_platformer.tscn and press F6.
5. Arrow keys move, Space jumps. Reach the gold object to return to Pong.

## Limitations
- This is a prototype using built-in geometry, not downloaded Kenney models.
- The return-to-Pong sequence currently reuses the first Pong scene. A separate final boss scene is not yet implemented.
- Not runtime-tested: Godot executable was unavailable in the authoring environment.
