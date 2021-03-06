{-# LANGUAGE OverloadedStrings #-}
module HWProtoNEState where

import Control.Monad.Reader
import qualified Data.ByteString.Char8 as B
--------------------------------------
import CoreTypes
import Actions
import Utils
import RoomsAndClients

handleCmd_NotEntered :: CmdHandler

handleCmd_NotEntered ["NICK", newNick] = do
    (ci, irnc) <- ask
    let cl = irnc `client` ci
    if not . B.null $ nick cl then return [ProtocolError "Nickname already chosen"]
        else
        if illegalName newNick then return [ByeClient "Illegal nickname"]
            else
            return $
                ModifyClient (\c -> c{nick = newNick}) :
                AnswerClients [sendChan cl] ["NICK", newNick] :
                [CheckRegistered | clientProto cl /= 0]

handleCmd_NotEntered ["PROTO", protoNum] = do
    (ci, irnc) <- ask
    let cl = irnc `client` ci
    if clientProto cl > 0 then return [ProtocolError "Protocol already known"]
        else
        if parsedProto == 0 then return [ProtocolError "Bad number"]
            else
            return $
                ModifyClient (\c -> c{clientProto = parsedProto}) :
                AnswerClients [sendChan cl] ["PROTO", B.pack $ show parsedProto] :
                [CheckRegistered | not . B.null $ nick cl]
    where
        parsedProto = case B.readInt protoNum of
                           Just (i, t) | B.null t -> fromIntegral i
                           _ -> 0


handleCmd_NotEntered ["PASSWORD", passwd] = do
    (ci, irnc) <- ask
    let cl = irnc `client` ci

    if passwd == webPassword cl then
        return $ JoinLobby : [AnswerClients [sendChan cl] ["ADMIN_ACCESS"] | isAdministrator cl]
        else
        return [ByeClient "Authentication failed"]


handleCmd_NotEntered _ = return [ProtocolError "Incorrect command (state: not entered)"]
