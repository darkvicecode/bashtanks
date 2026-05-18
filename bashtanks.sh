#!/bin/bash
############################################
#
#   Bash Tanks v.1.0
#
#    by: r0mmelr
#
#   https://github.com/darkvicecode/bashtanks
#    darkvice.net
#    dark-vice.com
#    codezero.cc
#    
#   GPL license
#
###########################################
#
#
# --- Configuration ---
WIDTH=$(tput cols)
HEIGHT=$(($(tput lines) - 6))
GRAVITY=1
SCALER=100 # For fixed-point math simulation

# Cloud State
clouds_x=(10 30 50 70 90 20 45 65 80)
clouds_y=(2 4 3 5 2 4 1 3 5)
clouds_shape=("  ___   " " (_____) " " (_____) " "  _____  " " (_____) " " (_____) " "  (____)  " " (_____) " "  ____  ")

# Tank Art
PLAYER1_TANK_ART=("   _   " " _[1]==*" "(o_o_o) ")
PLAYER2_TANK_ART=("   _   " "==[2]_  " "(o_o_o) ")
TANK_WIDTH=7; TANK_HEIGHT=3

# Pine Tree Art
PINE_TREE_ART=(
" /|\\"
" /|\\"
"/_|_\\"
"  |"
"  |"
)
PINE_TREE_WIDTH=5
PINE_TREE_HEIGHT=5

# --- Functions ---
sqrt() {
    local n=$1
    local i=1
    while [ $((i * i)) -le $n ]; do i=$((i + 1)); done
    echo $((i - 1))
}

draw_tank_art_intro() {
    local start_y=$1
    local start_x=$2
    local line_num=$start_y
    while IFS= read -r line; do
        tput cup $line_num $start_x
        echo "$line"
        ((line_num++))
    done << 'EOF'
                                                      _..----.._
                                                     ]_.--._____[
                                                   ___|'--'__..|--._
                               __               """    ;            :
                             ()_ """"---...__.'""!":  /    ____      :
                                """---...__\]..__] | /    [ XX ]      :
                                           """!--./ /      """"       :
                                    __  ...._____;""'.__________..--..:_
                                   /  !"''''''!''''''''''|''''/' ' ' ' "--..__  __..
                                  /  /.--.    |          |  .'          ' ' '.""--.{'.
              _...__            >=7 //.-.:    |          |.'             \ ._.__  ' '""'.
           .-' /    """"----..../ "">==7-.....:______    |                \| |  "";.;-"> 
           """";           __.."   .--"/"""""----...."""""----.....H_______\_!....'----""""]
         _!.-=_.            """""""""""""""                   ;"""
        /   .-";-.'--...___     ." .-""; ';""-""-...^..__...-v.^___,  ,__v.__..--^"--""-v.^v,
       ;   ;   |'.         """-/ ./;  ;   ;\P.        ;   ;        """"____;  ;.--""""// '""<,
       ;   ;   | 1            ;  ;  '.: .'  ;<   ___.-'._.'------""""""____'..'.--""";;'  o ';
       '.   \__:/__           ;  ;--""()_   ;'  /___ .-" ____---""""""" __.._ __._   '>.,  ,/;"
         \   \    /"""<--...__;  '_.-'/; ""; ;.'.'  "-..'    "-.      /"/    `__. '.   "---";"
          '.  'v ; ;     ;;    \  \ .'  \ ; ////    _.-" "-._   ;    : ;   .-'__ '. ;   .^\".'"
            '.  '; '.   .'/     '. `-.__.' /;;;   .o__.---.__o. ;    : ;   '""";;""' ;v^" .^"
              '-. '-.___.'<__v.^,v'.  '-.-' ;|:   '    :      ` ;v^v^'.'.    .;'.__/_..-'"
                 '-...__.___...---""'-.   '-'.;\     'WW\     .'_____..>."^"-""""""""    r0mr0m
                                       '--..__ '"._..'  '"-;;"""
EOF
}

init_terrain() {
    # Initialize with a lower base height
    for ((x=0; x<WIDTH; x++)); do terrain[$x]=8; trees[$x]=0; done

    # Add mountains that stay below clouds
    for ((a=0; a<12; a++)); do
        local arch_w=$((RANDOM % (WIDTH/4) + WIDTH/8))
        local arch_start=$((RANDOM % (WIDTH - arch_w)))
        # Toggle between positive (mountain) and negative (valley), max height ~7 (reduced from 10)
        local arch_h=$(( (RANDOM % 2 == 0 ? 1 : -1) * (RANDOM % 4 + 3) ))
        for ((x=0; x<arch_w; x++)); do
            local tx=$((arch_start + x))
            local angle=$(( x * 180 / arch_w ))
            local h=$(( (arch_h * $(get_sin $angle)) / 100 ))
            terrain[$tx]=$(( terrain[$tx] + h ))
        done
    done
    # Final smoothing pass
    for ((x=1; x<WIDTH-1; x++)); do terrain[$x]=$(( (terrain[x-1] + terrain[x] + terrain[x+1]) / 3 )); done
    # Keep terrain above ground
    for ((x=0; x<WIDTH; x++)); do [[ ${terrain[$x]} -lt 2 ]] && terrain[$x]=2; done
    
    # Add dense trees
    local max_trees=40
    local trees_occupied=()
    for ((i=0; i<WIDTH; i++)); do trees_occupied[$i]=0; done 

    for ((i=0; i<max_trees; i++)); do
        local attempts=0
        while true; do
            local tx=$(( RANDOM % (WIDTH - PINE_TREE_WIDTH) )) 
            
            # Check for overlap with player tanks
            local overlap_tank="false"
            if [[ $tx -ge $((player1_x - PINE_TREE_WIDTH)) && $tx -le $((player1_x + TANK_WIDTH + 3)) ]]; then overlap_tank="true"; fi
            if [[ $tx -ge $((player2_x - PINE_TREE_WIDTH)) && $tx -le $((player2_x + TANK_WIDTH + 3)) ]]; then overlap_tank="true"; fi

            if [[ "$overlap_tank" == "true" ]]; then
                ((attempts++)); [[ $attempts -gt 1000 ]] && break 
                continue
            fi

            # Check for overlap with already placed trees + spacing
            local overlap_tree_and_spacing="false"
            local check_start_area=$((tx - 3 < 0 ? 0 : tx - 3)) 
            local check_end_area=$((tx + PINE_TREE_WIDTH + 3 - 1 > WIDTH - 1 ? WIDTH - 1 : tx + PINE_TREE_WIDTH + 3 - 1))
            
            for ((j=check_start_area; j<=check_end_area; j++)); do
                if [[ ${trees_occupied[$j]} -eq 1 ]]; then overlap_tree_and_spacing="true"; break; fi
            done

            if [[ "$overlap_tree_and_spacing" == "false" ]]; then
                trees[$tx]=$PINE_TREE_HEIGHT
                for ((j=0; j<PINE_TREE_WIDTH; j++)); do 
                    if [[ $((tx + j)) -lt $WIDTH ]]; then trees_occupied[$((tx + j))]=1; fi
                done
                break
            fi
            ((attempts++)); [[ $attempts -gt 1000 ]] && break
        done
    done
}

draw_clouds() {
    for i in "${!clouds_x[@]}"; do
        local cx=${clouds_x[$i]}; local cy=${clouds_y[$i]}; local shape=${clouds_shape[$i]}
        if [[ $cx -ge 0 && $cx -lt $((WIDTH - ${#shape})) ]]; then
            tput cup $cy $cx
            echo -n "$shape"
        fi
    done
}

# Optimized move_clouds for local redraw
clear_cloud() {
    local cx=$1; local cy=$2; local shape=$3
    if [[ $cx -ge 0 && $cx -lt $((WIDTH - ${#shape})) ]]; then
        tput cup $cy $cx
        echo -n "$(printf '%*s' "${#shape}" '')" # Print spaces to clear
    fi
}

move_clouds() {
    for i in "${!clouds_x[@]}"; do
        clear_cloud ${clouds_x[$i]} ${clouds_y[$i]} "${clouds_shape[$i]}" # Clear old cloud position
        clouds_x[$i]=$(( (clouds_x[$i] + 1) % WIDTH ))
        draw_clouds_part ${clouds_x[$i]} ${clouds_y[$i]} "${clouds_shape[$i]}" # Draw new cloud position
    done
}

draw_clouds_part() { # Draws a single cloud at specified position
    local cx=$1; local cy=$2; local shape=$3
    if [[ $cx -ge 0 && $cx -lt $((WIDTH - ${#shape})) ]]; then
        tput cup $cy $cx
        echo -n "$shape"
    fi
}


# Optimized draw_column to only redraw necessary parts
draw_column() {
    local x=$1
    [[ $x -lt 0 || $x -ge $WIDTH ]] && return
    local h=${terrain[$x]}
    
    # Redraw terrain (if visible)
    for ((y=0; y<h; y++)); do tput cup $((HEIGHT - y)) $x; echo -n "#"; done

    # Redraw pine trees (if any, centered around x)
    for ((tree_root_x_search=x-PINE_TREE_WIDTH+1; tree_root_x_search<=x; tree_root_x_search++)); do
        if [[ $tree_root_x_search -ge 0 && ${trees[$tree_root_x_search]} -gt 0 ]]; then # Found a tree rooted at tree_root_x_search
            local tree_start_col=$tree_root_x_search
            local art_col_offset=$((x - tree_start_col)) # Which character in the PINE_TREE_ART line to get

            for ((line_idx=0; line_idx<PINE_TREE_HEIGHT; line_idx++)); do
                local char_to_draw="${PINE_TREE_ART[$line_idx]:$art_col_offset:1}" # Get char for this column
                if [[ "$char_to_draw" != " " ]]; then
                    tput cup $((HEIGHT - h - PINE_TREE_HEIGHT + line_idx)) $x
                    echo -n "$char_to_draw"
                fi
            done
            return # A character from a tree was drawn, so we are done with trees for this column
        fi
    done
    
    # Redraw tanks (if overlapping this column)
    # P1
    if [[ $x -ge $player1_x && $x -lt $((player1_x + TANK_WIDTH)) ]]; then
        local ox=$((x - player1_x))
        for ((line_idx=0; line_idx<TANK_HEIGHT; line_idx++)); do
            tput cup $((HEIGHT - terrain[$player1_x] - TANK_HEIGHT + line_idx)) $x
            echo -n "${PLAYER1_TANK_ART[$line_idx]:$ox:1}"
        done
    fi
    # P2
    if [[ $x -ge $player2_x && $x -lt $((player2_x + TANK_WIDTH)) ]]; then
        local ox=$((x - player2_x))
        for ((line_idx=0; line_idx<TANK_HEIGHT; line_idx++)); do
            tput cup $((HEIGHT - terrain[$player2_x] - TANK_HEIGHT + line_idx)) $x
            echo -n "${PLAYER2_TANK_ART[$line_idx]:$ox:1}"
        done
    fi
}

draw_ui() {
    tput cup "$((HEIGHT + 2))" "0"; tput el; echo "P1 HP: $player1_hp | P2 HP: $player2_hp | Turn: Player $turn"
}

draw_lightning() {
    [[ $((RANDOM % 3)) -ne 0 ]] && return # 33% chance
    local lx=$(( RANDOM % WIDTH )); local ly=0; tput bold
    local path_y=(); local path_x=()
    
    # Trace the bolt path down to the terrain
    while [[ $ly -lt $(( HEIGHT - terrain[lx] )) ]]; do
        path_y+=($ly); path_x+=($lx)
        ((ly++)); ((lx += RANDOM % 3 - 1))
        [[ $lx -lt 0 ]] && lx=0; [[ $lx -ge $WIDTH ]] && lx=$((WIDTH-1))
    done

    # Draw the bolt
    for ((i=0; i<${#path_x[@]}; i++)); do
        tput cup ${path_y[$i]} ${path_x[$i]}; echo -n "V"
    done
    sleep 0.08
    
    # Clear the bolt gradually to create a 'fade' effect
    for ((i=0; i<${#path_x[@]}; i++)); do
        tput cup ${path_y[$i]} ${path_x[$i]}; echo -n " "
        sleep 0.01
    done
    tput sgr0

    # Surgical Cleanup: Redraw only the columns hit by lightning
    declare -A seen_col
    for ((i=0; i<${#path_x[@]}; i++)); do
        local col=${path_x[$i]}
        if [[ -z "${seen_col[$col]}" ]]; then
            draw_column "$col"
            # Refresh clouds in this column
            for j in "${!clouds_x[@]}"; do
                local cx=${clouds_x[$j]}; local cy=${clouds_y[$j]}; local shape=${clouds_shape[$j]}
                if [[ $col -ge $cx && $col -lt $((cx + ${#shape})) ]]; then
                    draw_clouds_part $cx $cy "$shape"
                fi
            done
            seen_col[$col]=1
        fi
    done
}

draw_screen() {
    tput clear
    draw_clouds
    for ((x=0; x<WIDTH; x++)); do
        local h=${terrain[$x]}; [[ $h -gt HEIGHT ]] && h=$HEIGHT
        for ((y=0; y<h; y++)); do tput cup $((HEIGHT - y)) $x; echo -n "#"; done
        draw_column $x
    done
    # Redraw tanks initially
    for ((dx=0; dx<TANK_WIDTH; dx++)); do draw_column $((player1_x + dx)); done
    for ((dx=0; dx<TANK_WIDTH; dx++)); do draw_column $((player2_x + dx)); done
    draw_ui
}

draw_explosion() {
    local ex=$1; local ey=$2; local is_hit=$3
    local old_chars=()
    # Frame 1
    tput cup $((HEIGHT - ey)) $ex; echo "*"; old_chars+=("$((HEIGHT - ey)) $ex *"); sleep 0.1
    # Frame 2
    tput cup $((HEIGHT - ey - 1)) $ex; echo "|"; old_chars+=("$((HEIGHT - ey - 1)) $ex |")
    tput cup $((HEIGHT - ey)) $((ex - 2)); echo ".***."; old_chars+=("$((HEIGHT - ey)) $((ex - 2)) .***.")
    tput cup $((HEIGHT - ey + 1)) $ex; echo "|"; old_chars+=("$((HEIGHT - ey + 1)) $ex |"); sleep 0.2
    if [[ "$is_hit" == "true" ]]; then
        # Frame 3
        tput cup $((HEIGHT - ey - 1)) $((ex - 2)); echo "o O o"; old_chars+=("$((HEIGHT - ey - 1)) $((ex - 2)) o O o")
        tput cup $((HEIGHT - ey)) $((ex - 3)); echo ". ( @ ) ."; old_chars+=("$((HEIGHT - ey)) $((ex - 3)) . ( @ ) .")
        tput cup $((HEIGHT - ey + 1)) $((ex - 2)); echo "o O o"; old_chars+=("$((HEIGHT - ey + 1)) $((ex - 2)) o O o"); sleep 0.4
        # Frame 4
        tput cup $((HEIGHT - ey - 3)) $ex; echo "."; old_chars+=("$((HEIGHT - ey - 3)) $ex .")
        tput cup $((HEIGHT - ey - 2)) $((ex - 2)); echo ". o ."; old_chars+=("$((HEIGHT - ey - 2)) $((ex - 2)) . o .")
        tput cup $((HEIGHT - ey - 1)) $((ex - 4)); echo ".  ( O )  ."; old_chars+=("$((HEIGHT - ey - 1)) $((ex - 4)) .  ( O )  .")
        tput cup $((HEIGHT - ey)) $((ex - 5)); echo ",   .   ,"; old_chars+=("$((HEIGHT - ey)) $((ex - 5)) ,   .   ,")
        tput cup $((HEIGHT - ey + 1)) $((ex - 2)); echo "' . '"; old_chars+=("$((HEIGHT - ey + 1)) $((ex - 2)) ' . '"); sleep 0.6
        # Frame 5
        tput cup $((HEIGHT - ey - 3)) $((ex - 1)); echo "o o"; old_chars+=("$((HEIGHT - ey - 3)) $((ex - 1)) o o")
        tput cup $((HEIGHT - ey - 2)) $ex; echo "O"; old_chars+=("$((HEIGHT - ey - 2)) $ex O")
        tput cup $((HEIGHT - ey - 1)) $((ex - 1)); echo ". ."; old_chars+=("$((HEIGHT - ey - 1)) $((ex - 1)) . ."); sleep 0.7
    fi
    # Clear explosion marks and redraw affected columns
    for entry in "${old_chars[@]}"; do
        read -r y x char_str <<< "$entry"
        tput cup $y $x
        echo -n "$(printf '%*s' "${#char_str}" '')" # Clear with spaces
    done
    for ((dx=-5; dx<=5; dx++)); do
        draw_column $((ex + dx)) # Redraw terrain, trees, tanks
        # Also redraw clouds that might have been cleared
        local target_x=$((ex + dx))
        for i in "${!clouds_x[@]}"; do
            local cx=${clouds_x[$i]}; local cy=${clouds_y[$i]}; local shape=${clouds_shape[$i]}
            if [[ $target_x -ge $cx && $target_x -lt $((cx + ${#shape})) ]]; then
                draw_clouds_part $cx $cy "$shape"
            fi
        done
    done
}




############################################
#
##   Bash Tanks v.1.0
#
##    by: r0mmelr
#
##   https://github.com/darkvicecode/bashtanks
#    darkvice.net
#    dark-vice.com
#    codezero.cc
#    
#    GPL license
#    
############################################




draw_burst() {
    local fx=$((RANDOM % (WIDTH - 10) + 5)); local fy=$((RANDOM % (HEIGHT - 10) + 5)); local old_chars=()
    for r in 1 2 3; do
        tput cup $((HEIGHT - fy - r)) $fx; echo "|"; old_chars+=("$((HEIGHT - fy - r)) $fx |")
        tput cup $((HEIGHT - fy + r)) $fx; echo "|"; old_chars+=("$((HEIGHT - fy + r)) $fx |")
        tput cup $((HEIGHT - fy)) $((fx - r * 2)); echo "+"; old_chars+=("$((HEIGHT - fy)) $((fx - r * 2)) +")
        tput cup $((HEIGHT - fy)) $((fx + r * 2)); echo "+"; old_chars+=("$((HEIGHT - fy)) $((fx + r * 2)) +")
        tput cup $((HEIGHT - fy - r)) $((fx - r)); echo "/"; old_chars+=("$((HEIGHT - fy - r)) $((fx - r)) /")
        tput cup $((HEIGHT - fy - r)) $((fx + r)); echo "\\"; old_chars+=("$((HEIGHT - fy - r)) $((fx + r)) \\")
        tput cup $((HEIGHT - fy + r)) $((fx - r)); echo "\\"; old_chars+=("$((HEIGHT - fy + r)) $((fx - r)) \\")
        tput cup $((HEIGHT - fy + r)) $((fx + r)); echo "/"; old_chars+=("$((HEIGHT - fy + r)) $((fx + r)) /")
        sleep 0.03
    done
    # Clear burst marks and redraw affected columns
    for entry in "${old_chars[@]}"; do read -r y x char_str <<< "$entry"; tput cup $y $x; echo -n "$(printf '%*s' "${#char_str}" '')"; done
    for ((dx=-6; dx<=6; dx++)); do
        draw_column $((fx + dx)) # Redraw terrain, trees, tanks
        local target_x=$((fx + dx))
        for i in "${!clouds_x[@]}"; do
            local cx=${clouds_x[$i]}; local cy=${clouds_y[$i]}; local shape=${clouds_shape[$i]}
            if [[ $target_x -ge $cx && $target_x -lt $((cx + ${#shape})) ]]; then
                draw_clouds_part $cx $cy "$shape"
            fi
        done
    done
}

get_sin() { local deg=$1; [[ $deg -lt 0 ]] && deg=$(( -deg )); [[ $deg -gt 180 ]] && deg=$(( deg % 180 )); if [ $deg -gt 90 ]; then deg=$((180 - deg)); fi; if [ $deg -le 30 ]; then echo $((deg * 166 / 100)); elif [ $deg -le 60 ]; then echo $((50 + (deg-30) * 123 / 100)); else echo $((87 + (deg-60) * 43 / 100)); fi; }
get_cos() { local deg=$1; if [ $deg -gt 90 ]; then echo -$(( $(get_sin $((deg - 90))) )); else get_sin $(( 90 - deg )); fi; }

simulate_shot() {
    local sx=$1; local sy=$2; local sa=$3; local sp=$4; local side=$5
    local svx=$(( (sp * $(get_cos $sa)) / 50 )); local svy=$(( (sp * $(get_sin $sa)) / 50 ))
    [[ $side -eq 2 ]] && svx=$(( -svx ))
    local scx=$((sx * SCALER)); local scy=$((sy * SCALER)); local st=0
    while true; do
        ((st++)); local spx=$((scx / SCALER)); local spy=$((scy / SCALER))
        if [[ $spx -lt 0 || $spx -ge $WIDTH || $spy -lt 0 ]]; then echo "-1"; return; fi
        if [[ $side -eq 1 && $spx -ge $player2_x && $spx -lt $((player2_x + TANK_WIDTH)) && $spy -le $((terrain[player2_x] + TANK_HEIGHT)) ]]; then echo "$spx"; return; fi
        if [[ $side -eq 2 && $spx -ge $player1_x && $spx -lt $((player1_x + TANK_WIDTH)) && $spy -le $((terrain[player1_x] + TANK_HEIGHT)) ]]; then echo "$spx"; return; fi
        local tree_root_x=$((spx - (PINE_TREE_WIDTH / 2)))
        if [[ ${trees[$tree_root_x]} -gt 0 && $spx -ge $tree_root_x && $spx -lt $((tree_root_x + PINE_TREE_WIDTH)) && $spy -le $((terrain[$tree_root_x] + PINE_TREE_HEIGHT)) ]]; then echo "$spx"; return; fi
        if [[ $spy -le $((terrain[spx])) ]]; then echo "$spx"; return; fi
        scx=$((scx + svx)); scy=$((scy + svy)); svy=$((svy - GRAVITY * 4))
        [[ $st -gt 500 ]] && { echo "-1"; return; }
    done
}

update_tank_pos() {
    local old_x=$1; local new_x=$2
    for ((idx_x=old_x; idx_x<old_x+TANK_WIDTH; idx_x++)); do
        for ((idx_y=0; idx_y<TANK_HEIGHT; idx_y++)); do tput cup $((HEIGHT - terrain[old_x] - TANK_HEIGHT + idx_y)) $idx_x; echo -n " "; done
        draw_column $idx_x
        local target_x=$idx_x
        for i in "${!clouds_x[@]}"; do
            local cx=${clouds_x[$i]}; local cy=${clouds_y[$i]}; local shape=${clouds_shape[$i]}
            if [[ $target_x -ge $cx && $target_x -lt $((cx + ${#shape})) ]]; then draw_clouds_part $cx $cy "$shape"; fi
        done
    done
    for ((idx_x=new_x; idx_x<new_x+TANK_WIDTH; idx_x++)); do draw_column $idx_x; done
}

fire() {
    local angle=$1; local power=$2; local current_player=$turn
    local start_x=$((current_player == 1 ? player1_x : player2_x))
    local start_y=$((terrain[$start_x] + TANK_HEIGHT))
    local vx=$(( (power * $(get_cos $angle)) / 50 )); [[ $turn -eq 2 ]] && vx=$(( -vx ))
    local vy=$(( (power * $(get_sin $angle)) / 50 ))
    local cur_x=$((start_x * SCALER)); local cur_y=$((start_y * SCALER)); local first_step="true"
    while true; do
        local plot_x=$((cur_x / SCALER)); local plot_y=$((cur_y / SCALER))
        if [[ $plot_x -lt 0 || $plot_x -ge $WIDTH || $plot_y -lt 0 ]]; then break; fi
        if [[ $plot_y -lt $HEIGHT ]]; then
            tput cup $((HEIGHT - plot_y)) $plot_x; echo -n "*"; sleep 0.02; tput cup $((HEIGHT - plot_y)) $plot_x; echo -n " "
            if [[ $plot_y -le $((terrain[plot_x] + 5)) ]]; then draw_column $plot_x; fi
        fi
        if [[ "$first_step" == "true" ]]; then first_step="false"; cur_x=$((cur_x + vx)); cur_y=$((cur_y + vy)); vy=$((vy - GRAVITY * 4)); continue; fi

        local is_hit="false"; local hit_power=25 
        if [[ $current_player -ne 1 && $plot_x -ge $player1_x && $plot_x -lt $((player1_x + TANK_WIDTH)) && $plot_y -le $((terrain[player1_x] + TANK_HEIGHT)) ]]; then player1_hp=$((player1_hp - hit_power)); is_hit="true"; fi
        if [[ $current_player -ne 2 && $plot_x -ge $player2_x && $plot_x -lt $((player2_x + TANK_WIDTH)) && $plot_y -le $((terrain[player2_x] + TANK_HEIGHT)) ]]; then player2_hp=$((player2_hp - hit_power)); is_hit="true"; fi
        local tree_root_x=$((plot_x - (PINE_TREE_WIDTH / 2)))
        if [[ ${trees[$tree_root_x]} -gt 0 && $plot_x -ge $tree_root_x && $plot_x -lt $((tree_root_x + PINE_TREE_WIDTH)) && $plot_y -le $((terrain[$tree_root_x] + PINE_TREE_HEIGHT)) ]]; then trees[$tree_root_x]=0; is_hit="true"; fi
        if [[ "$is_hit" == "true" ]]; then draw_explosion $plot_x $plot_y "true"; draw_ui; break
        elif [[ $plot_y -le $((terrain[$plot_x])) ]]; then
            for ((dx=-8; dx<=8; dx++)); do
                local tx=$((plot_x + dx)); if [[ $tx -ge 0 && $tx -lt $WIDTH ]]; then
                    local dist=$(( dx < 0 ? -dx : dx )); local blast_depth=$(( 10 - dist ))
                    terrain[$tx]=$(( terrain[$tx] - blast_depth )); [[ ${terrain[$tx]} -lt 0 ]] && terrain[$tx]=0; draw_column $tx; fi; done
            draw_explosion $plot_x $plot_y "false"; draw_ui; break
        else cur_x=$((cur_x + vx)); cur_y=$((cur_y + vy)); vy=$((vy - GRAVITY * 4)); continue; fi
    done
}

# --- Main Game ---
while true; do
    terrain=(); trees=(); player1_x=5; player2_x=$((WIDTH - (TANK_WIDTH + 5))); player1_hp=100; player2_hp=100; turn=1
    tput clear; draw_tank_art_intro 1 2; menu_x=100; tput cup 2 $menu_x; echo "=== BASH TANKS ==="
    tput cup 4 $menu_x; echo "Select Mode:"; tput cup 5 $menu_x; echo "1) Player vs AI (Easy)"
    tput cup 6 $menu_x; echo "2) Player vs AI (Normal)"; tput cup 7 $menu_x; echo "3) Player vs AI (Hard)"
    tput cup 8 $menu_x; echo "4) Player vs Player"; tput cup 9 $menu_x; echo "Q) Quit Game"
    tput cup 11 $menu_x; echo -n "Choice: "; read game_mode
    case $game_mode in 
        1) ai_skill="easy"; mode="pve" ;; 
        2) ai_skill="normal"; mode="pve" ;; 
        3) ai_skill="hard"; mode="pve" ;; 
        4) mode="pvp" ;; 
        [qQ]) tput clear; exit 0 ;; 
        *) ai_skill="normal"; mode="pve" ;; 
    esac
    # --- Init Stats ---
    start_time=$(date +%s)
    p1_shots=0; p1_hits=0; p2_shots=0; p2_hits=0

    init_terrain; draw_screen
    while [[ $player1_hp -gt 0 && $player2_hp -gt 0 ]]; do
        draw_lightning; draw_ui
        if [[ $turn -eq 1 ]]; then
            tput cup "$((HEIGHT + 3))" "0"; tput el; echo -n "Player 1 - Move (-5 to 5): "; read move
            [[ -z "$move" ]] && move=0; [[ $move -gt 5 ]] && move=5; [[ $move -lt -5 ]] && move=-5
            old_x=$player1_x; player1_x=$(( player1_x + move )); [[ $player1_x -lt 0 ]] && player1_x=0; [[ $player1_x -ge $((WIDTH-TANK_WIDTH)) ]] && player1_x=$((WIDTH - TANK_WIDTH - 1))
            update_tank_pos $old_x $player1_x; tput cup "$((HEIGHT + 3))" "0"; tput el; echo -n "Player 1 - Angle (0-90): "; read angle
            tput cup "$((HEIGHT + 3))" "0"; tput el; echo -n "Player 1 - Power (10-100): "; read power; [[ -z "$angle" ]] && angle=45; [[ -z "$power" ]] && power=50
            ((p1_shots++)); p2_hp_pre=$player2_hp
            fire "$angle" "$power"
            [[ $player2_hp -lt $p2_hp_pre ]] && ((p1_hits++))
        else
            if [[ "$mode" == "pvp" ]]; then
                tput cup "$((HEIGHT + 3))" "0"; tput el; echo -n "Player 2 - Move (-5 to 5): "; read move
                [[ -z "$move" ]] && move=0; [[ $move -gt 5 ]] && move=5; [[ $move -lt -5 ]] && move=-5
                old_x=$player2_x; player2_x=$(( player2_x + move )); [[ $player2_x -lt 0 ]] && player2_x=0; [[ $player2_x -ge $((WIDTH-TANK_WIDTH)) ]] && player2_x=$((WIDTH - TANK_WIDTH - 1))
                update_tank_pos $old_x $player2_x; tput cup "$((HEIGHT + 3))" "0"; tput el; echo -n "Player 2 - Angle (0-90): "; read angle
                tput cup "$((HEIGHT + 3))" "0"; tput el; echo -n "Player 2 - Power (10-100): "; read power; [[ -z "$angle" ]] && angle=45; [[ -z "$power" ]] && power=50
                ((p2_shots++)); p1_hp_pre=$player1_hp
                fire "$angle" "$power"
                [[ $player1_hp -lt $p1_hp_pre ]] && ((p2_hits++))
            else
                tput cup "$((HEIGHT + 3))" "0"; tput el; echo "Player 2 (AI) is thinking..."; sleep 0.5
                # ... (AI logic remains) ...
                old_x=$player2_x; best_pos=$player2_x; max_score=-999
                for ((m=-5; m<=5; m++)); do
                    tx=$((player2_x + m)); if [[ $tx -ge 0 && $tx -lt $((WIDTH-TANK_WIDTH)) ]]; then
                        score=$(( terrain[tx] * 10 )); dist=$(( tx - player1_x )); [[ $dist -lt 0 ]] && dist=$(( -dist ))
                        [[ $dist -lt 30 ]] && score=$(( score - 50 )); [[ $score -gt $max_score ]] && { max_score=$score; best_pos=$tx; }; fi; done
                player2_x=$best_pos; update_tank_pos $old_x $player2_x
                best_angle=45; best_power=50; min_err=999
                for ta in 35 45 60; do
                    dist=$(( player2_x - player1_x )); [[ $dist -lt 0 ]] && dist=$(( -dist ))
                    s=$(get_sin $ta); c=$(get_cos $ta); [[ $c -lt 0 ]] && c=$(( -c ))
                    tp=$(sqrt $(( (dist * 500000) / (s * c + 1) )))
                    for p_off in -4 -2 0 2 4; do
                        cp=$((tp + p_off)); [[ $cp -lt 10 || $cp -gt 100 ]] && continue
                        land=$(simulate_shot $player2_x $((terrain[player2_x]+TANK_HEIGHT)) $ta $cp 2)
                        if [[ $land -ne -1 ]]; then
                            err=$(( land - player1_x )); [[ $err -lt 0 ]] && err=$(( -err ))
                            if [[ $err -lt $min_err ]]; then min_err=$err; best_angle=$ta; best_power=$cp; fi; fi; done; done
                err_scale=0; case $ai_skill in "easy") err_scale=12 ;; "hard") err_scale=2 ;; *) err_scale=6 ;; esac
                angle=$best_angle; power=$(( best_power + (RANDOM % (err_scale*2+1)) - err_scale ))
                [[ $power -lt 10 ]] && power=10; [[ $power -gt 100 ]] && power=100
                tput cup "$((HEIGHT + 3))" "0"; tput el; echo "Player 2 (AI) fires: Angle $angle, Power $power"; sleep 1
                ((p2_shots++)); p1_hp_pre=$player1_hp
                fire "$angle" "$power"
                [[ $player1_hp -lt $p1_hp_pre ]] && ((p2_hits++))
            fi
        fi
        move_clouds; draw_screen; [[ $turn -eq 1 ]] && turn=2 || turn=1
    done



    ############################################
    #
    ###   Bash Tanks v.1.0
    #
    ###    by: r0mmelr
    #
    ###   https://github.com/darkvicecode/bashtanks
    #    darkvice.net
    #    dark-vice.com
    #    codezero.cc
    #    
    #        GPL license
    #    
    #############################################


    # Final stats display
    end_time=$(date +%s)
    total_time=$((end_time - start_time))
    
    # Calculate accuracy
    p1_acc=0; [[ $p1_shots -gt 0 ]] && p1_acc=$(( p1_hits * 100 / p1_shots ))
    p2_acc=0; [[ $p2_shots -gt 0 ]] && p2_acc=$(( p2_hits * 100 / p2_shots ))

    # Keep game screen, draw frame and stats on top
    win_y=5; win_x=$((WIDTH / 2 - 15))
    winner="PLAYER 1"; shots=$p1_shots; acc=$p1_acc
    [[ $player1_hp -le 0 ]] && { winner="PLAYER 2"; shots=$p2_shots; acc=$p2_acc; }

    # Draw simple frame
    for ((i=0; i<10; i++)); do
        tput cup $((win_y + i)) $win_x; echo -n "|"
        tput cup $((win_y + i)) $((win_x + 30)); echo -n "|"
    done
    for ((i=0; i<=30; i++)); do
        tput cup $win_y $((win_x + i)); echo -n "-"
        tput cup $((win_y + 9)) $((win_x + i)); echo -n "-"
    done

    # Display stats inside frame
    tput cup $((win_y + 2)) $((win_x + 2)); echo "$winner WINS!"
    tput cup $((win_y + 3)) $((win_x + 2)); echo "Total Shots: $shots"
    tput cup $((win_y + 4)) $((win_x + 2)); echo "Accuracy: $acc%"
    tput cup $((win_y + 5)) $((win_x + 2)); echo "Game Time: ${total_time}s"
    
    while true; do
        tput cup $((win_y + 7)) $((win_x + 2)); echo "1) Menu  2) Exit"
        tput cup $((win_y + 8)) $((win_x + 2)); echo -n "Choice: "; read end_choice
        if [[ "$end_choice" == "1" ]]; then break; fi
        if [[ "$end_choice" == "2" ]]; then tput clear; exit 0; fi; done
done; tput clear
