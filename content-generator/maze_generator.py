"""
SVG Maze Generator for Low Dopamine Labyrinth App

Generates solvable mazes in three styles:
1. Grid mazes (recursive backtracking)
2. Shaped mazes (triangle, tree, mountain, diamond, circle)
3. Organic curved paths (for youngest kids ages 3-4)

Output: SVG strings and path data for the iOS app.
"""

import random
import math
import json
from typing import List, Tuple, Optional, Dict, Any


class Cell:
    """Represents a single cell in the maze grid."""
    def __init__(self, row: int, col: int):
        self.row = row
        self.col = col
        self.walls = {"top": True, "right": True, "bottom": True, "left": True}
        self.visited = False


class MazeGenerator:
    """Generates mazes using recursive backtracking."""

    def __init__(self, rows: int, cols: int, cell_size: int = 40, path_width: int = 30):
        self.rows = rows
        self.cols = cols
        self.cell_size = cell_size
        self.path_width = path_width
        self.grid: List[List[Cell]] = []
        self.solution_path: List[Tuple[int, int]] = []
        self._init_grid()

    def _init_grid(self):
        self.grid = [[Cell(r, c) for c in range(self.cols)] for r in range(self.rows)]

    def _get_neighbors(self, cell: Cell) -> List[Cell]:
        neighbors = []
        directions = [(-1, 0), (0, 1), (1, 0), (0, -1)]
        for dr, dc in directions:
            nr, nc = cell.row + dr, cell.col + dc
            if 0 <= nr < self.rows and 0 <= nc < self.cols:
                neighbor = self.grid[nr][nc]
                if not neighbor.visited:
                    neighbors.append(neighbor)
        return neighbors

    def _remove_wall(self, current: Cell, next_cell: Cell):
        dr = next_cell.row - current.row
        dc = next_cell.col - current.col
        if dr == -1:
            current.walls["top"] = False
            next_cell.walls["bottom"] = False
        elif dr == 1:
            current.walls["bottom"] = False
            next_cell.walls["top"] = False
        elif dc == 1:
            current.walls["right"] = False
            next_cell.walls["left"] = False
        elif dc == -1:
            current.walls["left"] = False
            next_cell.walls["right"] = False

    @staticmethod
    def _count_turns(path: List[Tuple[int, int]]) -> int:
        """Count direction changes in a solution path."""
        if len(path) < 3:
            return 0
        turns = 0
        for i in range(2, len(path)):
            dr1 = path[i-1][0] - path[i-2][0]
            dc1 = path[i-1][1] - path[i-2][1]
            dr2 = path[i][0] - path[i-1][0]
            dc2 = path[i][1] - path[i-1][1]
            if (dr1, dc1) != (dr2, dc2):
                turns += 1
        return turns

    def _add_extra_connections(self, count: int, mask: Optional[set] = None):
        """Remove extra internal walls to create loops/cycles in the maze.

        Finds all walls between two adjacent in-maze cells and randomly
        removes `count` of them, giving the player multiple route choices.
        """
        # Collect all internal walls (between two adjacent visited cells that still have a wall)
        internal_walls = []
        for r in range(self.rows):
            for c in range(self.cols):
                if mask and (r, c) not in mask:
                    continue
                cell = self.grid[r][c]
                # Check right wall
                if cell.walls["right"] and c + 1 < self.cols:
                    if not mask or (r, c + 1) in mask:
                        internal_walls.append((r, c, "right"))
                # Check bottom wall
                if cell.walls["bottom"] and r + 1 < self.rows:
                    if not mask or (r + 1, c) in mask:
                        internal_walls.append((r, c, "bottom"))

        random.shuffle(internal_walls)
        removed = 0
        for r, c, direction in internal_walls:
            if removed >= count:
                break
            cell = self.grid[r][c]
            if direction == "right":
                neighbor = self.grid[r][c + 1]
                cell.walls["right"] = False
                neighbor.walls["left"] = False
            elif direction == "bottom":
                neighbor = self.grid[r + 1][c]
                cell.walls["bottom"] = False
                neighbor.walls["top"] = False
            removed += 1

    def generate(self, start: Tuple[int, int] = (0, 0), mask: Optional[set] = None,
                 end: Optional[Tuple[int, int]] = None, min_solution_ratio: float = 0.0,
                 min_turns: int = 0, extra_connections: int = 0):
        """Generate maze using recursive backtracking with optional cell mask.

        If min_solution_ratio > 0 and end is provided, regenerates until the
        solution path visits at least that fraction of the total cells.
        min_turns enforces a minimum number of direction changes in the solution.
        This prevents trivially short or straight-line paths.
        extra_connections: number of extra walls to remove to create loops.
        """
        total_cells = len(mask) if mask else self.rows * self.cols
        max_attempts = 50

        for attempt in range(max_attempts):
            self._init_grid()
            if mask:
                for r in range(self.rows):
                    for c in range(self.cols):
                        if (r, c) not in mask:
                            self.grid[r][c].visited = True

            stack = []
            current = self.grid[start[0]][start[1]]
            current.visited = True
            stack.append(current)

            while stack:
                neighbors = self._get_neighbors(current)
                if neighbors:
                    next_cell = random.choice(neighbors)
                    self._remove_wall(current, next_cell)
                    next_cell.visited = True
                    stack.append(current)
                    current = next_cell
                else:
                    current = stack.pop()

            # Add extra connections (loops) after the spanning tree is built
            if extra_connections > 0:
                self._add_extra_connections(extra_connections, mask)

            # Check solution quality if requirements specified
            if end and (min_solution_ratio > 0 or min_turns > 0):
                solution = self.solve(start, end)
                ratio = len(solution) / total_cells if total_cells > 0 else 0
                turns = self._count_turns(solution)
                if ratio >= min_solution_ratio and turns >= min_turns:
                    return
                # Otherwise loop and regenerate
            else:
                return

    def solve(self, start: Tuple[int, int], end: Tuple[int, int]) -> List[Tuple[int, int]]:
        """Find solution path using BFS."""
        from collections import deque
        visited = set()
        parent = {}
        queue = deque([start])
        visited.add(start)

        while queue:
            r, c = queue.popleft()
            if (r, c) == end:
                path = []
                pos = end
                while pos != start:
                    path.append(pos)
                    pos = parent[pos]
                path.append(start)
                path.reverse()
                self.solution_path = path
                return path

            cell = self.grid[r][c]
            moves = []
            if not cell.walls["top"]:
                moves.append((r - 1, c))
            if not cell.walls["bottom"]:
                moves.append((r + 1, c))
            if not cell.walls["left"]:
                moves.append((r, c - 1))
            if not cell.walls["right"]:
                moves.append((r, c + 1))

            for nr, nc in moves:
                if 0 <= nr < self.rows and 0 <= nc < self.cols and (nr, nc) not in visited:
                    visited.add((nr, nc))
                    parent[(nr, nc)] = (r, c)
                    queue.append((nr, nc))

        return []

    def to_svg_walls(self, offset_x: int = 0, offset_y: int = 0, mask: Optional[set] = None) -> str:
        """Generate SVG path data for maze walls."""
        paths = []
        cs = self.cell_size
        for r in range(self.rows):
            for c in range(self.cols):
                if mask and (r, c) not in mask:
                    continue
                cell = self.grid[r][c]
                x = offset_x + c * cs
                y = offset_y + r * cs
                if cell.walls["top"]:
                    paths.append(f"M {x} {y} L {x + cs} {y}")
                if cell.walls["right"]:
                    paths.append(f"M {x + cs} {y} L {x + cs} {y + cs}")
                if cell.walls["bottom"]:
                    paths.append(f"M {x} {y + cs} L {x + cs} {y + cs}")
                if cell.walls["left"]:
                    paths.append(f"M {x} {y} L {x} {y + cs}")
        return " ".join(paths)

    def solution_to_svg_path(self, offset_x: int = 0, offset_y: int = 0) -> str:
        """Generate SVG path for the solution."""
        if not self.solution_path:
            return ""
        cs = self.cell_size
        half = cs // 2
        points = []
        for r, c in self.solution_path:
            x = offset_x + c * cs + half
            y = offset_y + r * cs + half
            points.append((x, y))
        if not points:
            return ""
        d = f"M {points[0][0]} {points[0][1]}"
        for x, y in points[1:]:
            d += f" L {x} {y}"
        return d

    def to_svg_corridors(self, offset_x: int = 0, offset_y: int = 0, mask: Optional[set] = None) -> str:
        """Generate SVG path data for corridor-style rendering.

        Draws lines between cell centers where walls are removed,
        rendered with wide stroke + round line caps = natural corridor look.
        """
        paths = []
        cs = self.cell_size
        half = cs // 2
        for r in range(self.rows):
            for c in range(self.cols):
                if mask and (r, c) not in mask:
                    continue
                cell = self.grid[r][c]
                cx = offset_x + c * cs + half
                cy = offset_y + r * cs + half
                # Only draw right and bottom connections to avoid duplicates
                if not cell.walls["right"] and c + 1 < self.cols:
                    if not mask or (r, c + 1) in mask:
                        nx = offset_x + (c + 1) * cs + half
                        paths.append(f"M {cx} {cy} L {nx} {cy}")
                if not cell.walls["bottom"] and r + 1 < self.rows:
                    if not mask or (r + 1, c) in mask:
                        ny = offset_y + (r + 1) * cs + half
                        paths.append(f"M {cx} {cy} L {cx} {ny}")
        # Add dots at each cell center for round nodes
        for r in range(self.rows):
            for c in range(self.cols):
                if mask and (r, c) not in mask:
                    continue
                cx = offset_x + c * cs + half
                cy = offset_y + r * cs + half
                paths.append(f"M {cx} {cy} L {cx} {cy}")
        return " ".join(paths)


class ShapeMask:
    """Generates cell masks for shaped mazes."""

    @staticmethod
    def triangle(rows: int, cols: int) -> set:
        mask = set()
        for r in range(rows):
            progress = r / max(rows - 1, 1)
            width = max(1, int(cols * progress))
            start_c = (cols - width) // 2
            for c in range(start_c, start_c + width):
                if 0 <= c < cols:
                    mask.add((r, c))
        return mask

    @staticmethod
    def tree(rows: int, cols: int) -> set:
        mask = set()
        trunk_width = max(2, cols // 5)
        trunk_height = max(2, rows // 4)
        canopy_rows = rows - trunk_height
        for r in range(canopy_rows):
            progress = r / max(canopy_rows - 1, 1)
            width = max(2, int(cols * 0.3 + cols * 0.7 * progress))
            start_c = (cols - width) // 2
            for c in range(start_c, start_c + width):
                if 0 <= c < cols:
                    mask.add((r, c))
        trunk_start = (cols - trunk_width) // 2
        for r in range(canopy_rows, rows):
            for c in range(trunk_start, trunk_start + trunk_width):
                if 0 <= c < cols:
                    mask.add((r, c))
        return mask

    @staticmethod
    def mountain(rows: int, cols: int) -> set:
        mask = set()
        peak_col = cols // 2
        for r in range(rows):
            inv_progress = 1.0 - (r / max(rows - 1, 1))
            width = max(1, int(cols * (1.0 - inv_progress * 0.7)))
            start_c = peak_col - width // 2
            for c in range(start_c, start_c + width):
                if 0 <= c < cols:
                    mask.add((r, c))
        return mask

    @staticmethod
    def diamond(rows: int, cols: int) -> set:
        mask = set()
        mid_r = rows // 2
        for r in range(rows):
            dist = abs(r - mid_r)
            frac = 1.0 - dist / max(mid_r, 1)
            width = max(1, int(cols * frac))
            start_c = (cols - width) // 2
            for c in range(start_c, start_c + width):
                if 0 <= c < cols:
                    mask.add((r, c))
        return mask

    @staticmethod
    def circle(rows: int, cols: int) -> set:
        mask = set()
        cr, cc = rows / 2, cols / 2
        radius = min(rows, cols) / 2 - 0.5
        for r in range(rows):
            for c in range(cols):
                if ((r - cr + 0.5) ** 2 + (c - cc + 0.5) ** 2) <= radius ** 2:
                    mask.add((r, c))
        return mask

    @staticmethod
    def moon(rows: int, cols: int) -> set:
        """Crescent moon shape — full circle with inner circle cut out offset to one side."""
        mask = set()
        cr, cc = rows / 2, cols / 2
        outer_r = min(rows, cols) / 2 - 0.5
        # Inner circle offset to create crescent
        inner_r = outer_r * 0.72
        inner_cc = cc + outer_r * 0.38
        for r in range(rows):
            for c in range(cols):
                in_outer = ((r - cr + 0.5) ** 2 + (c - cc + 0.5) ** 2) <= outer_r ** 2
                in_inner = ((r - cr + 0.5) ** 2 + (c - inner_cc + 0.5) ** 2) <= inner_r ** 2
                if in_outer and not in_inner:
                    mask.add((r, c))
        return mask

    @staticmethod
    def shell(rows: int, cols: int) -> set:
        """Scallop shell shape — broad rounded fan with a narrower hinged base."""
        mask = set()
        for r in range(rows):
            progress = r / max(rows - 1, 1)
            if progress < 0.14:
                width_ratio = 0.18 + progress * 1.1
            else:
                eased = (progress - 0.14) / 0.86
                width_ratio = 0.94 - 0.58 * (eased ** 0.82)
            width = max(2, int(cols * width_ratio))
            center_shift = int((0.5 - progress) * cols * 0.04)
            start_c = (cols - width) // 2 + center_shift
            for c in range(start_c, start_c + width):
                if 0 <= c < cols:
                    mask.add((r, c))
        return mask

    @staticmethod
    def rocket(rows: int, cols: int) -> set:
        """Rocket ship — pointed nose cone, rectangular body, flared fins at base."""
        mask = set()
        body_width = max(3, cols // 3)
        body_start_c = (cols - body_width) // 2

        # Nose cone (top 28%): narrows to a point
        nose_rows = max(3, rows * 28 // 100)
        for r in range(nose_rows):
            progress = r / max(nose_rows - 1, 1)
            width = max(1, round(body_width * progress))
            start_c = (cols - width) // 2
            for c in range(start_c, start_c + width):
                if 0 <= c < cols:
                    mask.add((r, c))

        # Body (middle 55%)
        body_rows = max(3, rows * 55 // 100)
        for r in range(nose_rows, nose_rows + body_rows):
            for c in range(body_start_c, body_start_c + body_width):
                if 0 <= c < cols:
                    mask.add((r, c))

        # Fins (bottom 17%): flare outward
        fin_start = nose_rows + body_rows
        extra = max(2, cols // 7)
        fin_width = min(cols - 2, body_width + extra * 2)
        for r in range(fin_start, rows):
            progress = (r - fin_start) / max(rows - fin_start - 1, 1)
            current_width = body_width + round(extra * 2 * progress)
            start_c = (cols - current_width) // 2
            for c in range(start_c, start_c + current_width):
                if 0 <= c < cols:
                    mask.add((r, c))
        return mask


class OrganicPathGenerator:
    """Generates curved paths for youngest kids (ages 3-4).

    style="simple"    — gentle S-curve from corner to corner (few turns)
    style="winding"   — canvas-filling snake path with U-turns
    style="labyrinth" — grid-based Hamiltonian path: complex, non-obvious,
                        looks like a real maze but has one clear wide route
    style="flower"    — daisy/flower: N petal loops around a hub, items at petal tips
    """

    def __init__(self, width: int = 600, height: int = 500, path_width: int = 35):
        self.width = width
        self.height = height
        self.path_width = path_width

    def generate(self, num_turns: int = 4, style: str = "labyrinth",
                 grid_cols: int = 7, grid_rows: int = 5,
                 num_petals: int = 6, item_emoji: str = "🌸") -> Dict[str, Any]:
        if style == "flower":
            return self._generate_flower(num_petals, item_emoji)
        if style == "labyrinth":
            return self._generate_labyrinth(grid_cols, grid_rows)
        if style == "winding":
            return self._generate_winding(num_rows=num_turns)
        return self._generate_simple(num_turns)

    # ------------------------------------------------------------------
    # Flower style
    # ------------------------------------------------------------------

    def _generate_flower(self, num_petals: int = 6,
                         item_emoji: str = "🌸") -> Dict[str, Any]:
        """Daisy/flower path: N teardrop petal loops radiating from a center hub.

        Layout
        ------
        - Petal 0 points DOWN (start: Denny at bottom petal tip).
        - Petals 1..N-1 visited clockwise; each traced as a teardrop loop.
        - Items placed at tips of petals 1..N-1 (all except start petal).
        - Path exits upward after the last petal; end point is above the flower
          (Maya waits there).

        Difficulty scaling
        ------------------
          5 petals  → easy,   path_width ≈ 32 px
          10 petals → medium, path_width ≈ 24 px
          20 petals → hard,   path_width ≈ 15 px
        """
        import math

        cx = self.width  / 2.0
        cy = self.height / 2.0
        margin = 52.0

        # Petal reach from center (shrink slightly for more petals)
        max_r = min(cx - margin, cy - margin)
        shrink = max(0.72, 1.0 - (num_petals - 5) * 0.008)
        petal_len = max_r * 0.82 * shrink

        # Distance at which the petal is widest (used for mid-waypoints)
        D = petal_len * 0.55

        # Petal half-width: 65% of the angular spacing at distance D,
        # but at least 14 px so even 20-petal paths are traceable.
        spacing_at_D = D * math.pi / num_petals   # half of arc between neighbors
        petal_hw = max(14.0, spacing_at_D * 0.65)

        # Path stroke width — thinner for more petals
        path_w = max(14, 34 - (num_petals - 5))

        # ---- angle helpers (screen coords: y increases downward) --------
        # Petal 0 at angle π/2 (= pointing DOWN in screen).
        # For even N, offset by half a step so no petal sits exactly at top
        # (avoids the exit stem clashing with a petal tip).
        base_angle = math.pi / 2
        if num_petals % 2 == 0:
            base_angle += math.pi / num_petals

        def pa(i: int) -> float:
            """Screen angle of petal i."""
            return base_angle + 2 * math.pi * i / num_petals

        def tip(i: int):
            a = pa(i)
            return (cx + petal_len * math.cos(a),
                    cy + petal_len * math.sin(a))

        def mid(i: int, side: float):
            """Waypoint at mid-distance D, perpendicular offset by petal_hw.
            side=+1 → left/out (going outward), side=-1 → right/in (returning).
            """
            a = pa(i)
            perp = a + math.pi / 2
            bx = cx + D * math.cos(a)
            by = cy + D * math.sin(a)
            return (bx + side * petal_hw * math.cos(perp),
                    by + side * petal_hw * math.sin(perp))

        # ---- build waypoints --------------------------------------------
        start_pt = tip(0)                          # Denny: bottom petal tip
        end_pt   = (cx, margin - 12.0)            # Maya: above the flower

        points: list = [start_pt]
        items:  list = []

        # Return leg of petal 0 (start → center)
        points.append(mid(0, -1))   # right side of petal 0
        points.append((cx, cy))     # hub center

        # Petals 1 … N-1
        for i in range(1, num_petals):
            points.append(mid(i, +1))   # left side (going out)
            t = tip(i)
            points.append(t)             # petal tip
            points.append(mid(i, -1))   # right side (returning)
            points.append((cx, cy))      # back to hub

            items.append({
                "x": round(t[0], 1),
                "y": round(t[1], 1),
                "emoji": item_emoji,
                "on_solution": True,
            })

        # Exit from hub up to Maya
        points.append((cx, margin + 8.0))   # just inside top area
        points.append(end_pt)

        result = self._build_result(points)
        result["items"]      = items
        result["path_width"] = path_w
        return result

    # ------------------------------------------------------------------
    # Labyrinth style — grid Hamiltonian path
    # ------------------------------------------------------------------

    def _find_hamiltonian_path(self, rows: int, cols: int,
                               start: tuple, end: tuple) -> list:
        """Randomised DFS with Warnsdorf tie-breaking.

        Tries to visit as many cells as possible (≥70% of grid) before
        reaching *end*.  Returns the best path found across several attempts.
        """
        dirs = [(0, 1), (0, -1), (1, 0), (-1, 0)]
        total = rows * cols

        def nbrs(r: int, c: int, visited: set) -> list:
            return [(r + dr, c + dc) for dr, dc in dirs
                    if 0 <= r + dr < rows and 0 <= c + dc < cols
                    and (r + dr, c + dc) not in visited]

        best: list = [start, end]

        for _ in range(60):
            visited: set = {start}
            path: list = [start]
            found = [False]

            def dfs(r: int, c: int) -> None:
                if found[0]:
                    return
                coverage = len(path) / total
                candidates = nbrs(r, c, visited)

                # Allow ending only once we've covered enough of the grid
                if end in candidates:
                    if coverage >= 0.70:
                        path.append(end)
                        found[0] = True
                        return
                    candidates = [n for n in candidates if n != end]

                # No moves: if we happen to be next to end still accept
                if not candidates:
                    if end in nbrs(r, c, visited - {end}) and coverage >= 0.55:
                        path.append(end)
                        found[0] = True
                    return

                random.shuffle(candidates)
                # Warnsdorf: fewest onward moves first → avoids dead-end traps
                candidates.sort(
                    key=lambda n: len(nbrs(n[0], n[1], visited | {n}))
                )

                for nr, nc in candidates:
                    visited.add((nr, nc))
                    path.append((nr, nc))
                    dfs(nr, nc)
                    if found[0]:
                        return
                    path.pop()
                    visited.remove((nr, nc))

            dfs(*start)

            if found[0] and len(path) > len(best):
                best = path[:]
            if len(best) >= total * 0.80 and best[-1] == end:
                break

        if best[-1] != end:
            best.append(end)
        return best

    def _generate_labyrinth(self, grid_cols: int = 7,
                            grid_rows: int = 5) -> Dict[str, Any]:
        """Grid Hamiltonian path → smooth organic-looking labyrinth route."""
        margin_x = 55
        margin_y = 60
        left  = margin_x
        right = self.width  - margin_x
        top   = margin_y
        bottom = self.height - margin_y

        cell_w = (right - left)  / (grid_cols - 1)
        cell_h = (bottom - top) / (grid_rows - 1)

        # grid row 0 = top, grid row (grid_rows-1) = bottom
        start_cell = (grid_rows - 1, 0)           # bottom-left
        end_cell   = (0,             grid_cols - 1) # top-right

        cells = self._find_hamiltonian_path(grid_rows, grid_cols,
                                            start_cell, end_cell)

        points: list = []
        for i, (gr, gc) in enumerate(cells):
            base_x = left   + gc * cell_w
            base_y = bottom - gr * cell_h   # row 0→bottom, row (rows-1)→top ... wait

            # grid row 0 = top → base_y = top + 0*cell_h = top
            # grid row (rows-1) = bottom → base_y = top + (rows-1)*cell_h = bottom
            base_y = top + gr * cell_h

            # Jitter tapers to zero at start/end for clean entry/exit
            is_edge = (i == 0 or i == len(cells) - 1)
            jitter_scale = 0.0 if is_edge else 0.9
            jx = random.uniform(-cell_w * 0.28, cell_w * 0.28) * jitter_scale
            jy = random.uniform(-cell_h * 0.28, cell_h * 0.28) * jitter_scale

            x = max(left + 5, min(right  - 5, base_x + jx))
            y = max(top  + 5, min(bottom - 5, base_y + jy))
            points.append((x, y))

        # Force exact canvas corners for start/end
        points[0]  = (left,  bottom)
        points[-1] = (right, top)

        return self._build_result(points)

    def _generate_simple(self, num_turns: int = 4) -> Dict[str, Any]:
        """Original simple S-curve path."""
        margin = 60
        points = []
        start_x = margin
        start_y = self.height - margin
        end_x = self.width - margin
        end_y = margin

        points.append((start_x, start_y))

        for i in range(num_turns):
            t = (i + 1) / (num_turns + 1)
            base_x = start_x + (end_x - start_x) * t
            base_y = start_y + (end_y - start_y) * t
            offset_x = random.uniform(-80, 80)
            offset_y = random.uniform(-40, 40)
            points.append((base_x + offset_x, base_y + offset_y))

        points.append((end_x, end_y))
        return self._build_result(points)

    def _generate_winding(self, num_rows: int = 4) -> Dict[str, Any]:
        """Snake path that fills the canvas — rows alternating left→right and right→left.

        num_rows controls complexity:
          3 → easy   (3 lanes, moderate winding)
          4 → medium (4 lanes)
          5 → hard   (5 lanes, dense winding)
        """
        margin_x = 55
        margin_y = 60
        left = margin_x
        right = self.width - margin_x
        top = margin_y
        bottom = self.height - margin_y

        usable_w = right - left
        usable_h = bottom - top
        row_spacing = usable_h / max(num_rows - 1, 1)

        # Points sampled along each horizontal lane
        pts_per_row = 7

        points: list = []

        for row_i in range(num_rows):
            going_right = (row_i % 2 == 0)
            row_y = bottom - row_i * row_spacing

            for j in range(pts_per_row):
                # Share the edge point with the previous row's last point
                if row_i > 0 and j == 0:
                    continue

                t = j / (pts_per_row - 1)  # 0 → 1 across the row

                base_x = (left + usable_w * t) if going_right else (right - usable_w * t)

                # Jitter tapers to zero at row edges so U-turns stay tidy
                edge_dist = min(t, 1.0 - t)          # 0 at edges, 0.5 in middle
                jitter_scale = min(edge_dist * 4, 1.0)

                jitter_x = random.uniform(-28, 28) * jitter_scale
                jitter_y = random.uniform(-row_spacing * 0.22, row_spacing * 0.22) * jitter_scale

                x = max(left + 8, min(right - 8, base_x + jitter_x))
                y = max(top + 8, min(bottom - 8, row_y + jitter_y))
                points.append((x, y))

        # Force exact start (bottom-left) and end (top-right)
        points[0] = (left, bottom)
        points[-1] = (right, top)

        return self._build_result(points)

    def _build_result(self, points: list) -> Dict[str, Any]:
        """Convert waypoint list into the standard maze_data dict."""
        svg_path = f"M {points[0][0]:.1f} {points[0][1]:.1f}"
        for i in range(1, len(points) - 1):
            cx = points[i][0]
            cy = points[i][1]
            nx = (points[i][0] + points[i + 1][0]) / 2
            ny = (points[i][1] + points[i + 1][1]) / 2
            svg_path += f" Q {cx:.1f} {cy:.1f} {nx:.1f} {ny:.1f}"
        svg_path += f" L {points[-1][0]:.1f} {points[-1][1]:.1f}"

        segments = [
            {
                "start": {"x": round(points[i][0], 1), "y": round(points[i][1], 1)},
                "end":   {"x": round(points[i + 1][0], 1), "y": round(points[i + 1][1], 1)},
            }
            for i in range(len(points) - 1)
        ]

        return {
            "svg_path": svg_path,
            "path_width": self.path_width,
            "start_point": {"x": round(points[0][0], 1), "y": round(points[0][1], 1)},
            "end_point":   {"x": round(points[-1][0], 1), "y": round(points[-1][1], 1)},
            "control_points": [{"x": round(p[0], 1), "y": round(p[1], 1)} for p in points],
            "segments": segments,
            "canvas_width": self.width,
            "canvas_height": self.height,
        }


class FullMazeGenerator:
    """High-level maze generator that combines all maze types."""

    SHAPE_MASKS = {
        "rect": None,
        "triangle": ShapeMask.triangle,
        "tree": ShapeMask.tree,
        "mountain": ShapeMask.mountain,
        "diamond": ShapeMask.diamond,
        "circle": ShapeMask.circle,
        "shell": ShapeMask.shell,
        "moon": ShapeMask.moon,
        "rocket": ShapeMask.rocket,
    }

    @staticmethod
    def _rect_position(rows: int, cols: int, position_name: str) -> Optional[Tuple[int, int]]:
        """Map position name to cell coordinates for rectangular (non-masked) mazes."""
        positions = {
            "top_left": (0, 0),
            "top": (0, cols // 2),
            "top_right": (0, cols - 1),
            "left": (rows // 2, 0),
            "center": (rows // 2, cols // 2),
            "right": (rows // 2, cols - 1),
            "bottom_left": (rows - 1, 0),
            "bottom": (rows - 1, cols // 2),
            "bottom_right": (rows - 1, cols - 1),
        }
        return positions.get(position_name)

    @staticmethod
    def _braid_dead_ends(maze: MazeGenerator, mask: Optional[set] = None):
        """Remove one wall from every dead-end cell, eliminating all dead ends.

        A dead end has exactly one open passage.  We repeatedly scan and open a
        random closed wall on each dead-end cell until none remain.  This turns
        a perfect (tree) maze into a braided maze with multiple routes.
        """
        opposites = {"top": "bottom", "bottom": "top", "left": "right", "right": "left"}
        nbr_offsets = {"top": (-1, 0), "right": (0, 1), "bottom": (1, 0), "left": (0, -1)}

        changed = True
        while changed:
            changed = False
            for r in range(maze.rows):
                for c in range(maze.cols):
                    if mask and (r, c) not in mask:
                        continue
                    cell = maze.grid[r][c]
                    open_passages = sum(1 for w in ["top", "right", "bottom", "left"]
                                        if not cell.walls[w])
                    if open_passages > 1:
                        continue
                    # Dead end — pick a random closed wall to an in-maze neighbour
                    closed = []
                    for wall, (dr, dc) in nbr_offsets.items():
                        if not cell.walls[wall]:
                            continue
                        nr, nc = r + dr, c + dc
                        if not (0 <= nr < maze.rows and 0 <= nc < maze.cols):
                            continue
                        if mask and (nr, nc) not in mask:
                            continue
                        closed.append((wall, nr, nc))
                    if closed:
                        wall, nr, nc = random.choice(closed)
                        cell.walls[wall] = False
                        maze.grid[nr][nc].walls[opposites[wall]] = False
                        changed = True

    @staticmethod
    def _solve_avoiding(maze: MazeGenerator, start: Tuple[int, int],
                        end: Tuple[int, int], blocked: set) -> bool:
        """BFS from start to end treating `blocked` cells as impassable."""
        from collections import deque
        visited: set = {start}
        queue: deque = deque([start])
        while queue:
            r, c = queue.popleft()
            if (r, c) == end:
                return True
            cell = maze.grid[r][c]
            nbrs = []
            if not cell.walls["top"]:    nbrs.append((r - 1, c))
            if not cell.walls["bottom"]: nbrs.append((r + 1, c))
            if not cell.walls["left"]:   nbrs.append((r, c - 1))
            if not cell.walls["right"]:  nbrs.append((r, c + 1))
            for pos in nbrs:
                if pos not in visited and pos not in blocked:
                    visited.add(pos)
                    queue.append(pos)
        return False

    def _place_avoid_items(
        self,
        maze: MazeGenerator,
        solution: List[Tuple[int, int]],
        start: Tuple[int, int],
        end: Tuple[int, int],
        num_owls: int,
        avoid_emoji: str,
        offset_x: int,
        offset_y: int,
        cell_size: int,
        mask: Optional[set] = None,
    ) -> List[Dict[str, Any]]:
        """Place avoid obstacles on junction cells along the solution path.

        Only places an obstacle where a detour exists (verified by BFS avoiding
        all placed obstacles + this candidate). Obstacles are spaced at least
        path_length / (num_owls + 1) steps apart along the solution.
        """
        half = cell_size // 2

        def open_passages(r: int, c: int) -> int:
            cell = maze.grid[r][c]
            return sum(1 for w in ["top", "right", "bottom", "left"] if not cell.walls[w])

        # Candidate: on solution, not start/end, has ≥2 open passages.
        # The BFS detour check below is the real guard — even a 2-passage cell
        # can have an alternate route if the maze is sufficiently braided.
        candidates = [
            (i, pos) for i, pos in enumerate(solution)
            if pos != start and pos != end and open_passages(*pos) >= 2
        ]

        min_gap = max(2, len(solution) // max(num_owls + 1, 1))

        selected: List[Tuple[int, Tuple[int, int]]] = []
        last_path_idx = -min_gap

        for path_idx, pos in candidates:
            if path_idx - last_path_idx < min_gap:
                continue
            blocked = {p for _, p in selected} | {pos}
            if self._solve_avoiding(maze, start, end, blocked):
                selected.append((path_idx, pos))
                last_path_idx = path_idx
            if len(selected) >= num_owls:
                break

        return [
            {"x": offset_x + c * cell_size + half,
             "y": offset_y + r * cell_size + half,
             "emoji": avoid_emoji,
             "on_solution": True}
            for _, (r, c) in selected
        ]

    def place_items(
        self,
        maze: MazeGenerator,
        solution: List[Tuple[int, int]],
        start: Tuple[int, int],
        end: Tuple[int, int],
        item_count: int,
        item_emoji: str,
        offset_x: int,
        offset_y: int,
        cell_size: int,
        mask: Optional[set] = None,
    ) -> List[Dict[str, Any]]:
        """Place collect items across solution AND branch paths.

        ~40% of items on the solution path, ~60% on non-solution cells,
        forcing the player to explore dead ends and alternate routes.
        """
        half = cell_size // 2

        solution_set = set(solution)
        solution_cells = [c for c in solution if c != start and c != end]

        # All reachable cells not on the solution path
        all_cells = set()
        for r in range(maze.rows):
            for c in range(maze.cols):
                if mask and (r, c) not in mask:
                    continue
                all_cells.add((r, c))
        branch_cells = [c for c in all_cells if c not in solution_set and c != start and c != end]

        # Split: ~40% on solution, ~60% on branches
        on_solution_count = max(1, item_count * 2 // 5)
        on_branch_count = item_count - on_solution_count

        # If not enough branch cells, put remaining on solution
        if len(branch_cells) < on_branch_count:
            on_branch_count = len(branch_cells)
            on_solution_count = item_count - on_branch_count

        random.shuffle(solution_cells)
        random.shuffle(branch_cells)

        chosen_solution = solution_cells[:min(on_solution_count, len(solution_cells))]
        chosen_branch = branch_cells[:min(on_branch_count, len(branch_cells))]

        items = []
        for r, c in chosen_solution:
            x = offset_x + c * cell_size + half
            y = offset_y + r * cell_size + half
            items.append({
                "x": x,
                "y": y,
                "emoji": item_emoji,
                "on_solution": True,
            })
        for r, c in chosen_branch:
            x = offset_x + c * cell_size + half
            y = offset_y + r * cell_size + half
            items.append({
                "x": x,
                "y": y,
                "emoji": item_emoji,
                "on_solution": False,
            })
        return items

    def generate_maze(
        self,
        difficulty: str = "easy",
        age: int = 4,
        shape: str = "rect",
        canvas_width: int = 600,
        canvas_height: int = 500,
        override_rows: Optional[int] = None,
        override_cols: Optional[int] = None,
        render_style: str = "walls",
        item_rule: Optional[str] = None,
        item_count: int = 0,
        item_emoji: Optional[str] = None,
        start_position: Optional[str] = None,
        end_position: Optional[str] = None,
    ) -> Dict[str, Any]:
        """Generate a complete maze with all data needed for the app.

        render_style: "walls" (default) or "corridor"
        item_rule: None or "collect"
        start_position/end_position: override start/end placement
        """
        path_width = 35 if age <= 4 else 25

        # Determine grid size based on difficulty and age
        if override_rows and override_cols:
            rows, cols = override_rows, override_cols
        elif age <= 4 and difficulty == "easy":
            rows, cols = (4, 5)
        else:
            sizes = {
                "easy": (5, 7),
                "medium": (7, 9),
                "hard": (9, 12),
            }
            rows, cols = sizes.get(difficulty, (7, 9))

        cell_size = min(
            (canvas_width - 40) // cols,
            (canvas_height - 40) // rows
        )
        cell_size = max(cell_size, 20)

        offset_x = (canvas_width - cols * cell_size) // 2
        offset_y = (canvas_height - rows * cell_size) // 2

        # Generate mask for shaped mazes
        mask = None
        mask_fn = self.SHAPE_MASKS.get(shape)
        if mask_fn:
            mask = mask_fn(rows, cols)

        maze = MazeGenerator(rows, cols, cell_size, path_width)

        # Find valid start/end within mask — pick maximally distant corners
        if mask:
            mask_list = sorted(mask)
            # Pick the two cells with maximum Manhattan distance
            best_dist = 0
            start, end = mask_list[0], mask_list[-1]
            # Check corners of the bounding box within the mask
            candidates = [mask_list[0], mask_list[-1]]
            min_r = min(r for r, c in mask_list)
            max_r = max(r for r, c in mask_list)
            min_c = min(c for r, c in mask_list)
            max_c = max(c for r, c in mask_list)
            for r, c in mask_list:
                if (r == min_r or r == max_r) and (c == min_c or c == max_c):
                    candidates.append((r, c))
            for a in candidates:
                for b in candidates:
                    d = abs(a[0] - b[0]) + abs(a[1] - b[1])
                    if d > best_dist:
                        best_dist = d
                        start, end = a, b
        else:
            start = (0, 0)
            end = (rows - 1, cols - 1)

        # Override start/end positions if specified
        if start_position and mask:
            mask_list = sorted(mask)
            pos_map = self._position_candidates(mask_list, rows, cols)
            if start_position in pos_map:
                start = random.choice(pos_map[start_position])
        if end_position and mask:
            mask_list = sorted(mask)
            pos_map = self._position_candidates(mask_list, rows, cols)
            if end_position in pos_map:
                candidates_end = [c for c in pos_map[end_position] if c != start]
                if candidates_end:
                    end = random.choice(candidates_end)

        # Override start/end for rect mazes (no mask)
        if not mask:
            if start_position:
                pos = self._rect_position(rows, cols, start_position)
                if pos:
                    start = pos
            if end_position:
                pos = self._rect_position(rows, cols, end_position)
                if pos and pos != start:
                    end = pos

        # Require solution to visit a meaningful fraction of cells
        # and have a minimum number of turns (no straight-line paths)
        min_ratio = {
            "easy": 0.3, "medium": 0.4, "hard": 0.4,
        }.get(difficulty, 0.3)
        min_turns = {
            "easy": 3, "medium": 5, "hard": 7,
        }.get(difficulty, 3)
        extra_conns = {
            "easy": 1, "medium": 4, "hard": 8,
        }.get(difficulty, 2)
        maze.generate(start, mask, end=end, min_solution_ratio=min_ratio,
                      min_turns=min_turns, extra_connections=extra_conns)

        # Avoid-type mazes need every dead end removed so detour routes always exist.
        if item_rule == "avoid":
            self._braid_dead_ends(maze, mask)

        solution = maze.solve(start, end)

        # Choose SVG rendering style
        if render_style == "corridor":
            svg_path = maze.to_svg_corridors(offset_x, offset_y, mask)
            maze_type_prefix = "corridor"
        else:
            svg_path = maze.to_svg_walls(offset_x, offset_y, mask)
            maze_type_prefix = "grid" if shape == "rect" else "shaped"

        solution_svg = maze.solution_to_svg_path(offset_x, offset_y)

        half = cell_size // 2
        start_x = offset_x + start[1] * cell_size + half
        start_y = offset_y + start[0] * cell_size + half
        end_x = offset_x + end[1] * cell_size + half
        end_y = offset_y + end[0] * cell_size + half

        # Build segments for hit testing from ALL open corridors (not just solution)
        segments = []
        for r in range(rows):
            for c in range(cols):
                if mask and (r, c) not in mask:
                    continue
                cell = maze.grid[r][c]
                if not cell.walls["right"] and c + 1 < cols:
                    if not mask or (r, c + 1) in mask:
                        segments.append({
                            "start": {
                                "x": offset_x + c * cell_size + half,
                                "y": offset_y + r * cell_size + half
                            },
                            "end": {
                                "x": offset_x + (c + 1) * cell_size + half,
                                "y": offset_y + r * cell_size + half
                            }
                        })
                if not cell.walls["bottom"] and r + 1 < rows:
                    if not mask or (r + 1, c) in mask:
                        segments.append({
                            "start": {
                                "x": offset_x + c * cell_size + half,
                                "y": offset_y + r * cell_size + half
                            },
                            "end": {
                                "x": offset_x + c * cell_size + half,
                                "y": offset_y + (r + 1) * cell_size + half
                            }
                        })

        if render_style == "corridor":
            maze_type = f"corridor_{shape}"
        else:
            maze_type = "grid" if shape == "rect" else f"shaped_{shape}"

        result = {
            "maze_type": maze_type,
            "svg_path": svg_path,
            "solution_path": solution_svg,
            "path_width": path_width,
            "cell_size": cell_size,
            "grid_rows": rows,
            "grid_cols": cols,
            "start_point": {"x": start_x, "y": start_y},
            "end_point": {"x": end_x, "y": end_y},
            "segments": segments,
            "canvas_width": canvas_width,
            "canvas_height": canvas_height,
            "complexity": difficulty,
            "shape": shape,
        }

        # Place collect items across the maze if requested
        if item_rule and item_count > 0 and item_emoji and solution:
            items = self.place_items(
                maze, solution, start, end,
                item_count, item_emoji,
                offset_x, offset_y, cell_size, mask,
            )
            result["items"] = items

        # Place avoid items on the solution path using the level's requested emoji.
        if item_rule == "avoid" and solution:
            num_owls = {"easy": 2, "medium": 3, "hard": 4}.get(difficulty, 2)
            avoid_items = self._place_avoid_items(
                maze, solution, start, end, num_owls, item_emoji or "🦉",
                offset_x, offset_y, cell_size, mask,
            )
            result["avoid_items"] = avoid_items

        return result

    @staticmethod
    def _position_candidates(mask_list: list, rows: int, cols: int) -> Dict[str, List[Tuple[int, int]]]:
        """Map position names to candidate cells within the mask."""
        min_r = min(r for r, c in mask_list)
        max_r = max(r for r, c in mask_list)
        min_c = min(c for r, c in mask_list)
        max_c = max(c for r, c in mask_list)
        mid_r = (min_r + max_r) // 2
        mid_c = (min_c + max_c) // 2
        positions: Dict[str, List[Tuple[int, int]]] = {
            "top": [], "bottom": [], "left": [], "right": [],
            "top_left": [], "top_right": [], "bottom_left": [], "bottom_right": [],
            "center": [],
        }
        for r, c in mask_list:
            if r == min_r:
                positions["top"].append((r, c))
            if r == max_r:
                positions["bottom"].append((r, c))
            if c == min_c:
                positions["left"].append((r, c))
            if c == max_c:
                positions["right"].append((r, c))
            if r == min_r and c <= mid_c:
                positions["top_left"].append((r, c))
            if r == min_r and c >= mid_c:
                positions["top_right"].append((r, c))
            if r == max_r and c <= mid_c:
                positions["bottom_left"].append((r, c))
            if r == max_r and c >= mid_c:
                positions["bottom_right"].append((r, c))
            if abs(r - mid_r) <= 1 and abs(c - mid_c) <= 1:
                positions["center"].append((r, c))
        return positions

    def to_full_svg(self, maze_data: Dict[str, Any], bg_color: str = "#4A90E2") -> str:
        """Render a complete SVG image for preview."""
        w = maze_data["canvas_width"]
        h = maze_data["canvas_height"]
        pw = maze_data["path_width"]
        sp = maze_data["start_point"]
        ep = maze_data["end_point"]

        svg = f"""<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">
  <rect width="{w}" height="{h}" fill="{bg_color}" rx="12"/>
"""
        if maze_data["maze_type"] == "organic":
            svg += f"""  <path d="{maze_data['svg_path']}" fill="none" stroke="white" stroke-width="{pw}" stroke-linecap="round" stroke-linejoin="round"/>
"""
        else:
            svg += f"""  <path d="{maze_data['svg_path']}" fill="none" stroke="white" stroke-width="3" stroke-linecap="round"/>
"""
        # NOTE: solution_path is stored in JSON for post-completion reveal only — not shown in SVG

        # Start marker — red circle with a triangular arrow (language-agnostic)
        svg += f"""  <circle cx="{sp['x']}" cy="{sp['y']}" r="14" fill="#E74C3C"/>
  <polygon points="{sp['x']-5},{sp['y']-6} {sp['x']+7},{sp['y']} {sp['x']-5},{sp['y']+6}" fill="white"/>
"""
        # End marker — gold star shape
        star_r = 12
        star_points = []
        for k in range(10):
            angle = math.pi / 2 + k * math.pi / 5
            r = star_r if k % 2 == 0 else star_r * 0.45
            sx = ep['x'] + r * math.cos(angle)
            sy = ep['y'] - r * math.sin(angle)
            star_points.append(f"{sx:.1f},{sy:.1f}")
        svg += f"""  <polygon points="{' '.join(star_points)}" fill="#F1C40F"/>
"""
        svg += "</svg>"
        return svg


def main():
    """Demo: generate sample mazes and save as SVG."""
    import os
    gen = FullMazeGenerator()
    output_dir = os.path.join(os.path.dirname(__file__), "output", "svg_previews")
    os.makedirs(output_dir, exist_ok=True)

    samples = [
        {"difficulty": "easy", "age": 3, "shape": "rect", "name": "easy_organic"},
        {"difficulty": "easy", "age": 5, "shape": "rect", "name": "easy_grid"},
        {"difficulty": "medium", "age": 5, "shape": "triangle", "name": "medium_triangle"},
        {"difficulty": "medium", "age": 5, "shape": "tree", "name": "medium_tree"},
        {"difficulty": "hard", "age": 6, "shape": "mountain", "name": "hard_mountain"},
        {"difficulty": "hard", "age": 6, "shape": "diamond", "name": "hard_diamond"},
    ]

    colors = ["#4A90E2", "#27AE60", "#2C3E50", "#27AE60", "#8B4513", "#9B59B6"]

    for i, sample in enumerate(samples):
        maze = gen.generate_maze(
            difficulty=sample["difficulty"],
            age=sample["age"],
            shape=sample["shape"],
        )
        svg = gen.to_full_svg(maze, colors[i])
        path = os.path.join(output_dir, f"{sample['name']}.svg")
        with open(path, "w") as f:
            f.write(svg)
        print(f"Generated: {path}")

        json_path = os.path.join(output_dir, f"{sample['name']}.json")
        with open(json_path, "w") as f:
            json.dump(maze, f, indent=2)


if __name__ == "__main__":
    main()
