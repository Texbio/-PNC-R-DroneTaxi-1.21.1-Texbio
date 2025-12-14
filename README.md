# PNC-R-DroneTaxi-Texbio
\- THIS VERSION WAS MADE WITH CLAUDE CODE (AI)
</br>\- If you do not know PneumaticCraft then learn that first.

## How to use
### Server Script
either drag the file in after downloading it, or use:
</br>```wget https://raw.githubusercontent.com/Texbio/-PNC-R-DroneTaxi-1.21.1-Texbio/refs/heads/main/server.lua```
</br>\- run `server`
### Taxi Script
either drag the file in after downloading it, or use:
</br>```wget https://raw.githubusercontent.com/Texbio/-PNC-R-DroneTaxi-1.21.1-Texbio/refs/heads/main/taxi.lua```
</br>\- run `taxi help` or `taxi`

### Downsides:
\- WE NEED TO TELEPORT INTO A LOADED CHUNK, check https://github.com/TeamPneumatic/pnc-repressurized/issues/1240

### Basics:
\- remove channel file(s): `rm .taxi_channel .taxi_server`
</br>\- make sure your main channel is unique. 0-65565 and write it down somewhere or use cc to read your channel file
</br>\- `taxi help` and `taxi`

## Demonstration video (too lazy to make updated version)

https://github.com/user-attachments/assets/47bf7075-92db-4804-97d5-8b9de7416599

### Upgrades
\- By the time you get into Drone stuff you should have pcbs automated or have 20+
</br>\- 1 Drone Interface

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
</br>\- Place 4 computers, 1 high up, 3 scattered, and chunk loaded. the further apart the better.
</br>\- In each computer: `gps host x y z`
</br>\- Testing GPS: `gps locate`

## License
Do not care too much, but its under MIT, because it was based on someone else's project [github](https://github.com/Ebonut/PNC-R-DroneTaxi) and MC3699's [yt video](https://www.youtube.com/watch?v=BL5QF4sl9RE)
