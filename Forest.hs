module Forest where

import CellularAutomata2D
import System.Random (randomRIO)

data Wood = Tree | Empty | Fire deriving (Show, Eq)

forest = do
    space <- randomSpace 150 150 [Empty, Tree]
    runCellularAutomata2D space [Tree, Empty, Fire] colors (makeMoorRule updateCell)

newFireProp = 1 - 0.999 :: Float
newTreeProp = 1 - 0.96 :: Float

updateCell Fire _ = return Empty
updateCell Tree friends = do
    newFire <- randomRIO (0,1)
    return $ if newFireProp >= newFire || Fire `elem` friends
        then Fire
        else Tree
updateCell Empty _ = do
    newTree <- randomRIO (0, 1)
    return $ if newTreeProp >= newTree
        then Tree
        else Empty

colors Fire = 4278190335
colors Tree = 3234243982
colors Empty = 0