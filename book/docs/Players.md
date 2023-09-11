**CARD** (<ins>card_id</ins>, name, _#player_id_)<br>
**GAME** (<ins>game_id</ins>, status, wager)<br>
**PLAYER** (<ins>player_id</ins>, address, color, _#game_id_)<br>
**SUPPLIES** (<ins>_#unit_id_</ins>, <ins>_#card_id_</ins>)<br>
**TERRITORY** (<ins>territory_id</ins>, name, position, neighbors, _#card_id_, _#player_id_)<br>
**UNIT** (<ins>unit_id</ins>, name, strength, _#territory_id_, _#player_id_)