module GameOfLife where

import CellularAutomata2D
import qualified Graphics.UI.SDL as SDL

gol :: Space -> IO ()
gol space = runCellularAutomata2D space [SDL.Pixel 0, SDL.Pixel 2334554] (makeTotalMoorRule [2,3] [3])

glieder = initSpace 20 20 (zip [(0,2),(1,2),(2,2),(2,1),(1,0)] (repeat 1))
