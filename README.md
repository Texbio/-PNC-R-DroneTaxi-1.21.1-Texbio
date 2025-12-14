# PNC-R-DroneTaxi-Texbio
\- THIS VERSION WAS MADE WITH CLAUDE CODE (AI)
</br>\- DOES NOT USE ADVANCED PERIPHERALS (it would know which chunks were loaded if it did, and be able to select players)
</br>\- If you do not know PneumaticCraft then learn that first.

## How to use
### Server Script
either drag the file in after downloading it, or use:
</br>```wget https://raw.githubusercontent.com/Texbio/-PNC-R-DroneTaxi-1.21.1-Texbio/refs/heads/main/server.lua```
</br>\- run `server` in your ***Advanced Computer***
### Taxi Script
either drag the file in after downloading it, or use:
</br>```wget https://raw.githubusercontent.com/Texbio/-PNC-R-DroneTaxi-1.21.1-Texbio/refs/heads/main/taxi.lua```
</br>\- run `taxi help` or `taxi` in your ***Advanced Pocket Computer*** + Ender Modem (craft together)

### Downsides:
\- WE NEED TO TELEPORT INTO A LOADED CHUNK, check https://github.com/TeamPneumatic/pnc-repressurized/issues/1240
</br>\- Drone refuses to teleport into blocks and we grab the player from 1.8 blocks above the player's feet.

## Demonstration video (too lazy to make updated version)
https://github.com/user-attachments/assets/47bf7075-92db-4804-97d5-8b9de7416599

## drone_generator.py
\- Creates an output which is pasted in the Programmer (upper left)
</br>```{"version":3,"widgets":[{"pos":{"x":72,"y":-19},"type":"pneumaticcraft:start"},{"pos":{"x":72,"y":3},"type":"pneumaticcraft:standby"},{"pos":{"x":72,"y":14},"inv":{},"type":"pneumaticcraft:computer_control"},{"area_type":{"type":"pneumaticcraft:box"},"pos":{"x":87,"y":-8},"pos1":[1292,69,2101],"pos2":[1292,69,2101],"type":"pneumaticcraft:area"},{"area_type":{"type":"pneumaticcraft:box"},"pos":{"x":87,"y":14},"pos1":[1292,67,2101],"pos2":[1292,67,2101],"type":"pneumaticcraft:area"},{"pos":{"x":72,"y":25},"type":"pneumaticcraft:teleport"},{"pos":{"x":72,"y":-8},"type":"pneumaticcraft:goto"},{"area_type":{"type":"pneumaticcraft:box"},"pos":{"x":87,"y":25},"pos1":[1292,69,2101],"pos2":[1292,69,2101],"type":"pneumaticcraft:area"}]}```
</br>(if you want to manually use the gps tool to set areas that is always an option)
<img width="750" alt="image" src="https://github.com/user-attachments/assets/34d05272-d80e-4337-8fd4-b725f810ae06" />
<img width="750" alt="image" src="https://github.com/user-attachments/assets/51b2aa14-225d-487d-8c4e-af68830c99ac" />
<img width="750" alt="image" src="https://github.com/user-attachments/assets/8f005378-d0eb-4cec-b591-2a954c1531c3" />
<img width="750" alt="image" src="https://github.com/user-attachments/assets/dce1b023-7c65-413a-8d8b-42f2bf1d0e3e" />
<img width="750" alt="image" src="https://github.com/user-attachments/assets/d0f7ee43-9959-44c5-b289-512ee1b3d067" />
<img width="750" alt="image" src="https://github.com/user-attachments/assets/256084d8-5f0a-4803-85aa-68017376c5ba" />



## Other Information
### Basics:
\- remove channel file(s): `rm .taxi_channel .taxi_server`
</br>\- make sure your main channel is unique. 0-65565 and write it down somewhere or use cc to read your channel file
</br>\- `taxi help` and `taxi`

### Items Required
\- Have alot of PCBs (Amadron tablet to buy alot of lubricant for speed upgrades)
</br>\- 1 Drone Interface
</br>\- 1 Drone
</br>\- 1 Advanced Computer + 1 Ender Modem (not counting gps)
</br>\- 1 Advanced Pocket Computer (craft with an ender modem), this is where the taxi script goes.

### Other Items
\- Safety Tube Module (prevents tubes from exploding)
</br>\- Pressure Gauge Tube Module + Module Expansion Card (prevents machines from exploding, turn on redstone input for the machine)
</br>\- Advanced Air Compressor (useful if you have infinite charcoal or coal)

### Upgrades
#### Changing station:
\- 1 dispenser upgrade
</br>\- 10 volume upgrades

#### Drone (normal):
\- 10 volume upgrades
</br>\- chunk load upgrade

#### All:
\- 10 speed upgrade all
</br>\- 1 security upgrade all (only put 1 in the drone!)

### GPS
\- I recommend adding a gps system, so you do not have to use the f3+c system; 4 computers with ender modems
</br>\- https://tweaked.cc/guide/gps_setup.html (make this but 10x bigger, using Ender Modems (normal modems only have 64 block range))
</br>\- Place 4 computers, 1 high up, 3 scattered, and chunk loaded. the further apart the better.
</br>\- In each computer: `gps host x y z`
</br>\- Testing GPS: `gps locate`

## License
Do not care too much, but its under MIT, because it was based on someone else's project [github](https://github.com/Ebonut/PNC-R-DroneTaxi) and MC3699's [yt video](https://www.youtube.com/watch?v=BL5QF4sl9RE)
