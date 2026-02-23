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

    def generate(self, start: Tuple[int, int] = (0, 0), mask: Optional[set] = None,
                 end: Optional[Tuple[int, int]] = None, min_solution_ratio: float = 0.0):
        """Generate maze using recursive backtracking with optional cell mask.

        If min_solution_ratio > 0 and end is provided, regenerates until the
        solution path visits at least that fraction of the total cells.
        This prevents trivially short paths through complex mazes.
        """
        total_cells = len(mask) if mask else self.rows * self.cols
        max_attempts = 20

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

            # Check solution length if requirements specified
            if min_solution_ratio > 0 and end:
                solution = self.solve(start, end)
                ratio = len(solution) / total_cells if total_cells > 0 else 0
                if ratio >= min_solution_ratio:
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


class OrganicPathGenerator:
    """Generates simple curved paths for youngest kids (ages 3-4)."""

    def __init__(self, width: int = 600, height: int = 500, path_width: int = 35):
        self.width = width
        self.height = height
        self.path_width = path_width

    def generate(self, num_turns: int = 4) -> Dict[str, Any]:
        """Generate a simple winding path with gentle curves."""
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

        # Build smooth SVG path using quadratic bezier curves
        svg_path = f"M {points[0][0]:.1f} {points[0][1]:.1f}"
        for i in range(1, len(points) - 1):
            cx = points[i][0]
            cy = points[i][1]
            nx = (points[i][0] + points[i + 1][0]) / 2
            ny = (points[i][1] + points[i + 1][1]) / 2
            svg_path += f" Q {cx:.1f} {cy:.1f} {nx:.1f} {ny:.1f}"
        svg_path += f" L {points[-1][0]:.1f} {points[-1][1]:.1f}"

        # Generate path segments for hit-testing
        segments = []
        for i in range(len(points) - 1):
            segments.append({
                "start": {"x": round(points[i][0], 1), "y": round(points[i][1], 1)},
                "end": {"x": round(points[i + 1][0], 1), "y": round(points[i + 1][1], 1)}
            })

        return {
            "svg_path": svg_path,
            "path_width": self.path_width,
            "start_point": {"x": round(points[0][0], 1), "y": round(points[0][1], 1)},
            "end_point": {"x": round(points[-1][0], 1), "y": round(points[-1][1], 1)},
            "control_points": [{"x": round(p[0], 1), "y": round(p[1], 1)} for p in points],
            "segments": segments,
            "canvas_width": self.width,
            "canvas_height": self.height
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
    }

    def place_items(
        self,
        maze: MazeGenerator,
        solution: List[Tuple[int, int]],
        start: Tuple[int, int],
        end: Tuple[int, int],
        item_rule: str,
        item_count: int,
        item_emoji: str,
        offset_x: int,
        offset_y: int,
        cell_size: int,
        mask: Optional[set] = None,
    ) -> List[Dict[str, Any]]:
        """Place items on or off the solution path.

        - collect: items on solution path cells (excluding start/end)
        - avoid: items on non-solution cells
        """
        half = cell_size // 2
        solution_set = set(solution)

        if item_rule == "collect":
            # Place on solution path cells, excluding start and end
            candidates = [cell for cell in solution if cell != start and cell != end]
        else:
            # Place on non-solution cells
            if mask:
                all_cells = list(mask)
            else:
                all_cells = [(r, c) for r in range(maze.rows) for c in range(maze.cols)]
            candidates = [cell for cell in all_cells if cell not in solution_set]

        random.shuffle(candidates)
        chosen = candidates[:min(item_count, len(candidates))]

        items = []
        for r, c in chosen:
            x = offset_x + c * cell_size + half
            y = offset_y + r * cell_size + half
            items.append({
                "x": x,
                "y": y,
                "emoji": item_emoji,
                "on_solution": (r, c) in solution_set,
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
        item_rule: None, "collect", or "avoid"
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

        # Require solution to visit a meaningful fraction of cells
        # Medium: >= 40% of cells, Hard: >= 50% of cells
        min_ratio = {"easy": 0.3, "medium": 0.4, "hard": 0.5}.get(difficulty, 0.3)
        maze.generate(start, mask, end=end, min_solution_ratio=min_ratio)
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

        # Build segments for hit testing from solution path
        segments = []
        if solution:
            for i in range(len(solution) - 1):
                r1, c1 = solution[i]
                r2, c2 = solution[i + 1]
                segments.append({
                    "start": {
                        "x": offset_x + c1 * cell_size + half,
                        "y": offset_y + r1 * cell_size + half
                    },
                    "end": {
                        "x": offset_x + c2 * cell_size + half,
                        "y": offset_y + r2 * cell_size + half
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

        # Place items if requested
        if item_rule and item_count > 0 and item_emoji and solution:
            items = self.place_items(
                maze, solution, start, end,
                item_rule, item_count, item_emoji,
                offset_x, offset_y, cell_size, mask,
            )
            result["items"] = items

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
