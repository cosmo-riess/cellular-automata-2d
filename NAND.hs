import Control.Monad (replicateM)

import CellularAutomata2D
import GUI

main :: IO ()
main = do
    asymNANDSpace
    mapM_ (\[isAnd, isMoor, withSelf] -> do
        putStr "isAnd: "
        print isAnd
        putStr "isMoor: "
        print isMoor
        putStr "withSelf: "
        print withSelf
        putStrLn ""
        logicSpace isAnd isMoor withSelf)
        (replicateM 3 [True, False])

logicSpace :: Bool -> Bool -> Bool -> IO ()
logicSpace isAnd isMoor withSelf = do
    space <- randomSpace (50, 50) [True, False] :: IO (Torus Bool)
    -- let space = initSpaceWithDefault False (50, 50) [] :: Torus Bool
    let ruleMaker = if isMoor then Rule moorIndexDeltas else Rule neumannIndexDeltas
    let logicFn = if isAnd then and else or
    let rule = ruleMaker (\self ns -> return $ not $ logicFn (if withSelf then self:ns else ns))
    runCellularAutomata2D space [True, False] colors rule

asymNANDSpace :: IO ()
asymNANDSpace = do
    space <- randomSpace (50, 50) [True, False] :: IO (Torus Bool)
    runCellularAutomata2D space [True, False] colors $ Rule moorIndexDeltas $ \self ns ->
        return $ not $ and $ self : take 3 ns
colors :: Bool -> Color
colors c
    | c = white
    | otherwise = black

