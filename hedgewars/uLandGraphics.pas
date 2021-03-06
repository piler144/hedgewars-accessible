(*
 * Hedgewars, a free turn based strategy game
 * Copyright (c) 2004-2011 Andrey Korotaev <unC0Rr@gmail.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 2 of the License
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA
 *)

{$INCLUDE "options.inc"}

unit uLandGraphics;
interface
uses uFloat, uConsts, uTypes;

type PRangeArray = ^TRangeArray;
     TRangeArray = array[0..31] of record
                                   Left, Right: LongInt;
                                   end;

function  addBgColor(OldColor, NewColor: LongWord): LongWord;
function  SweepDirty: boolean;
function  Despeckle(X, Y: LongInt): boolean;
function  CheckLandValue(X, Y: LongInt; LandFlag: Word): boolean;
function  DrawExplosion(X, Y, Radius: LongInt): Longword;
procedure DrawHLinesExplosions(ar: PRangeArray; Radius: LongInt; y, dY: LongInt; Count: Byte);
procedure DrawTunnel(X, Y, dX, dY: hwFloat; ticks, HalfWidth: LongInt);
procedure FillRoundInLand(X, Y, Radius: LongInt; Value: Longword);
procedure ChangeRoundInLand(X, Y, Radius: LongInt; doSet: boolean);
function  LandBackPixel(x, y: LongInt): LongWord;

function TryPlaceOnLand(cpX, cpY: LongInt; Obj: TSprite; Frame: LongInt; doPlace: boolean; indestructible: boolean): boolean;

implementation
uses SDLh, uLandTexture, uVariables, uUtils, uDebug;

function addBgColor(OldColor, NewColor: LongWord): LongWord;
// Factor ranges from 0 to 100% NewColor
var
    oRed, oBlue, oGreen, oAlpha, nRed, nBlue, nGreen, nAlpha: Byte;
begin
    // Get colors
    oAlpha := (OldColor shr 24) and $FF;
    oRed   := (OldColor shr 16) and $FF;
    oGreen := (OldColor shr 8) and $FF;
    oBlue  := (OldColor) and $FF;

    nAlpha := (NewColor shr 24) and $FF;
    nRed   := (NewColor shr 16) and $FF;
    nGreen := (NewColor shr 8) and $FF;
    nBlue  := (NewColor) and $FF;

    // Mix colors
    nAlpha := min(255, oAlpha + nAlpha);
    nRed   := ((oRed * oAlpha) + (nRed * (255-oAlpha))) div 255;
    nGreen := ((oGreen * oAlpha) + (nGreen * (255-oAlpha))) div 255;
    nBlue  := ((oBlue * oAlpha) + (nBlue * (255-oAlpha))) div 255;

    addBgColor := (nAlpha shl 24) or (nRed shl 16) or (nGreen shl 8) or (nBlue);
end;

procedure FillCircleLines(x, y, dx, dy: LongInt; Value: Longword);
var i: LongInt;
begin
if ((y + dy) and LAND_HEIGHT_MASK) = 0 then
    for i:= Max(x - dx, 0) to Min(x + dx, LAND_WIDTH - 1) do
        if (Land[y + dy, i] and lfIndestructible) = 0 then
            Land[y + dy, i]:= Value;
if ((y - dy) and LAND_HEIGHT_MASK) = 0 then
   for i:= Max(x - dx, 0) to Min(x + dx, LAND_WIDTH - 1) do
        if (Land[y - dy, i] and lfIndestructible) = 0 then
            Land[y - dy, i]:= Value;
if ((y + dx) and LAND_HEIGHT_MASK) = 0 then
    for i:= Max(x - dy, 0) to Min(x + dy, LAND_WIDTH - 1) do
        if (Land[y + dx, i] and lfIndestructible) = 0 then
            Land[y + dx, i]:= Value;
if ((y - dx) and LAND_HEIGHT_MASK) = 0 then
    for i:= Max(x - dy, 0) to Min(x + dy, LAND_WIDTH - 1) do
        if (Land[y - dx, i] and lfIndestructible) = 0 then
            Land[y - dx, i]:= Value;
end;

procedure ChangeCircleLines(x, y, dx, dy: LongInt; doSet: boolean);
var i: LongInt;
begin
if not doSet then
   begin
   if ((y + dy) and LAND_HEIGHT_MASK) = 0 then
      for i:= Max(x - dx, 0) to Min(x + dx, LAND_WIDTH - 1) do
          if (Land[y + dy, i] > 0) and (Land[y + dy, i] < 256) then dec(Land[y + dy, i]); // check > 0 because explosion can erase collision data
   if ((y - dy) and LAND_HEIGHT_MASK) = 0 then
      for i:= Max(x - dx, 0) to Min(x + dx, LAND_WIDTH - 1) do
          if (Land[y - dy, i] > 0) and (Land[y - dy, i] < 256) then dec(Land[y - dy, i]);
   if ((y + dx) and LAND_HEIGHT_MASK) = 0 then
      for i:= Max(x - dy, 0) to Min(x + dy, LAND_WIDTH - 1) do
          if (Land[y + dx, i] > 0) and (Land[y + dx, i] < 256) then dec(Land[y + dx, i]);
   if ((y - dx) and LAND_HEIGHT_MASK) = 0 then
      for i:= Max(x - dy, 0) to Min(x + dy, LAND_WIDTH - 1) do
          if (Land[y - dx, i] > 0) and (Land[y - dx, i] < 256) then dec(Land[y - dx, i]);
   end else
   begin
   if ((y + dy) and LAND_HEIGHT_MASK) = 0 then
      for i:= Max(x - dx, 0) to Min(x + dx, LAND_WIDTH - 1) do
          if (Land[y + dy, i] < 256) then
              inc(Land[y + dy, i]);
   if ((y - dy) and LAND_HEIGHT_MASK) = 0 then
      for i:= Max(x - dx, 0) to Min(x + dx, LAND_WIDTH - 1) do
          if (Land[y - dy, i] < 256) then
              inc(Land[y - dy, i]);
   if ((y + dx) and LAND_HEIGHT_MASK) = 0 then
      for i:= Max(x - dy, 0) to Min(x + dy, LAND_WIDTH - 1) do
          if (Land[y + dx, i] < 256) then
              inc(Land[y + dx, i]);
   if ((y - dx) and LAND_HEIGHT_MASK) = 0 then
      for i:= Max(x - dy, 0) to Min(x + dy, LAND_WIDTH - 1) do
          if (Land[y - dx, i] < 256) then
              inc(Land[y - dx, i]);
   end
end;

procedure FillRoundInLand(X, Y, Radius: LongInt; Value: Longword);
var dx, dy, d: LongInt;
begin
  dx:= 0;
  dy:= Radius;
  d:= 3 - 2 * Radius;
  while (dx < dy) do
     begin
     FillCircleLines(x, y, dx, dy, Value);
     if (d < 0)
     then d:= d + 4 * dx + 6
     else begin
          d:= d + 4 * (dx - dy) + 10;
          dec(dy)
          end;
     inc(dx)
     end;
  if (dx = dy) then FillCircleLines(x, y, dx, dy, Value);
end;

procedure ChangeRoundInLand(X, Y, Radius: LongInt; doSet: boolean);
var dx, dy, d: LongInt;
begin
  dx:= 0;
  dy:= Radius;
  d:= 3 - 2 * Radius;
  while (dx < dy) do
     begin
     ChangeCircleLines(x, y, dx, dy, doSet);
     if (d < 0)
     then d:= d + 4 * dx + 6
     else begin
          d:= d + 4 * (dx - dy) + 10;
          dec(dy)
          end;
     inc(dx)
     end;
  if (dx = dy) then ChangeCircleLines(x, y, dx, dy, doSet)
end;

procedure FillLandCircleLines0(x, y, dx, dy: LongInt);
var i, t: LongInt;
begin
t:= y + dy;
if (t and LAND_HEIGHT_MASK) = 0 then
    for i:= Max(x - dx, 0) to Min(x + dx, LAND_WIDTH - 1) do
        if (not isMap and ((Land[t, i] and lfIndestructible) = 0)) or ((Land[t, i] and lfBasic) <> 0) then
            if (cReducedQuality and rqBlurryLand) = 0 then
                LandPixels[t, i]:= 0
            else
                LandPixels[t div 2, i div 2]:= 0;

t:= y - dy;
if (t and LAND_HEIGHT_MASK) = 0 then
    for i:= Max(x - dx, 0) to Min(x + dx, LAND_WIDTH - 1) do
        if (not isMap and ((Land[t, i] and lfIndestructible) = 0)) or ((Land[t, i] and lfBasic) <> 0) then
            if (cReducedQuality and rqBlurryLand) = 0 then
                LandPixels[t, i]:= 0
            else
                LandPixels[t div 2, i div 2]:= 0;

t:= y + dx;
if (t and LAND_HEIGHT_MASK) = 0 then
    for i:= Max(x - dy, 0) to Min(x + dy, LAND_WIDTH - 1) do
        if (not isMap and ((Land[t, i] and lfIndestructible) = 0)) or ((Land[t, i] and lfBasic) <> 0) then
            if (cReducedQuality and rqBlurryLand) = 0 then
                LandPixels[t, i]:= 0
            else
                LandPixels[t div 2, i div 2]:= 0;

t:= y - dx;
if (t and LAND_HEIGHT_MASK) = 0 then
    for i:= Max(x - dy, 0) to Min(x + dy, LAND_WIDTH - 1) do
        if (not isMap and ((Land[t, i] and lfIndestructible) = 0)) or ((Land[t, i] and lfBasic) <> 0) then
            if (cReducedQuality and rqBlurryLand) = 0 then
                LandPixels[t, i]:= 0
            else
                LandPixels[t div 2, i div 2]:= 0;

end;

function FillLandCircleLinesBG(x, y, dx, dy: LongInt): Longword;
var i, t: LongInt;
    cnt: Longword;
begin
cnt:= 0;
t:= y + dy;
if (t and LAND_HEIGHT_MASK) = 0 then
   for i:= Max(x - dx, 0) to Min(x + dx, LAND_WIDTH - 1) do
       if ((Land[t, i] and lfBasic) <> 0) and not disableLandBack then
           begin
           inc(cnt);
           if (cReducedQuality and rqBlurryLand) = 0 then
               LandPixels[t, i]:= LandBackPixel(i, t)
           else
               LandPixels[t div 2, i div 2]:= LandBackPixel(i, t)
           end
       else
           if ((Land[t, i] and lfObject) <> 0) or (disableLandBack and ((Land[t, i] and lfIndestructible) = 0)) then
               if (cReducedQuality and rqBlurryLand) = 0 then
                   LandPixels[t, i]:= 0
               else
                   LandPixels[t div 2, i div 2]:= 0;

t:= y - dy;
if (t and LAND_HEIGHT_MASK) = 0 then
   for i:= Max(x - dx, 0) to Min(x + dx, LAND_WIDTH - 1) do
       if ((Land[t, i] and lfBasic) <> 0) and not disableLandBack then
           begin
           inc(cnt);
           if (cReducedQuality and rqBlurryLand) = 0 then
               LandPixels[t, i]:= LandBackPixel(i, t)
           else
               LandPixels[t div 2, i div 2]:= LandBackPixel(i, t)
           end
       else
           if ((Land[t, i] and lfObject) <> 0) or (disableLandBack and ((Land[t, i] and lfIndestructible) = 0)) then
               if (cReducedQuality and rqBlurryLand) = 0 then
                   LandPixels[t, i]:= 0
               else
                   LandPixels[t div 2, i div 2]:= 0;

t:= y + dx;
if (t and LAND_HEIGHT_MASK) = 0 then
   for i:= Max(x - dy, 0) to Min(x + dy, LAND_WIDTH - 1) do
       if ((Land[t, i] and lfBasic) <> 0) and not disableLandBack then
           begin
           inc(cnt);
           if (cReducedQuality and rqBlurryLand) = 0 then
               LandPixels[t, i]:= LandBackPixel(i, t)
           else
               LandPixels[t div 2, i div 2]:= LandBackPixel(i, t)
           end
       else
           if ((Land[t, i] and lfObject) <> 0) or (disableLandBack and ((Land[t, i] and lfIndestructible) = 0)) then
               if (cReducedQuality and rqBlurryLand) = 0 then
                   LandPixels[t, i]:= 0
               else
                   LandPixels[t div 2, i div 2]:= 0;

t:= y - dx;
if (t and LAND_HEIGHT_MASK) = 0 then
   for i:= Max(x - dy, 0) to Min(x + dy, LAND_WIDTH - 1) do
       if ((Land[t, i] and lfBasic) <> 0) and not disableLandBack then
           begin
           inc(cnt);
           if (cReducedQuality and rqBlurryLand) = 0 then
               LandPixels[t, i]:= LandBackPixel(i, t)
           else
               LandPixels[t div 2, i div 2]:= LandBackPixel(i, t)
           end
       else
           if ((Land[t, i] and lfObject) <> 0) or (disableLandBack and ((Land[t, i] and lfIndestructible) = 0)) then
              if (cReducedQuality and rqBlurryLand) = 0 then
                  LandPixels[t, i]:= 0
              else
                  LandPixels[t div 2, i div 2]:= 0;
FillLandCircleLinesBG:= cnt;
end;

procedure FillLandCircleLinesEBC(x, y, dx, dy: LongInt);
var i, t: LongInt;
begin
t:= y + dy;
if (t and LAND_HEIGHT_MASK) = 0 then
   for i:= Max(x - dx, 0) to Min(x + dx, LAND_WIDTH - 1) do
       if ((Land[t, i] and lfBasic) <> 0) or ((Land[t, i] and lfObject) <> 0) then
          begin
           if (cReducedQuality and rqBlurryLand) = 0 then
            LandPixels[t, i]:= cExplosionBorderColor
          else
            LandPixels[t div 2, i div 2]:= cExplosionBorderColor;

          Land[t, i]:= Land[t, i] or lfDamaged;
          //Despeckle(i, t);
          LandDirty[t div 32, i div 32]:= 1;
          end;

t:= y - dy;
if (t and LAND_HEIGHT_MASK) = 0 then
   for i:= Max(x - dx, 0) to Min(x + dx, LAND_WIDTH - 1) do
       if ((Land[t, i] and lfBasic) <> 0) or ((Land[t, i] and lfObject) <> 0) then
          begin
           if (cReducedQuality and rqBlurryLand) = 0 then
              LandPixels[t, i]:= cExplosionBorderColor
            else
              LandPixels[t div 2, i div 2]:= cExplosionBorderColor;
          Land[t, i]:= Land[t, i] or lfDamaged;
          //Despeckle(i, t);
          LandDirty[t div 32, i div 32]:= 1;
          end;

t:= y + dx;
if (t and LAND_HEIGHT_MASK) = 0 then
   for i:= Max(x - dy, 0) to Min(x + dy, LAND_WIDTH - 1) do
       if ((Land[t, i] and lfBasic) <> 0) or ((Land[t, i] and lfObject) <> 0) then
           begin
           if (cReducedQuality and rqBlurryLand) = 0 then
           LandPixels[t, i]:= cExplosionBorderColor
            else
           LandPixels[t div 2, i div 2]:= cExplosionBorderColor;

           Land[t, i]:= Land[t, i] or lfDamaged;
           //Despeckle(i, t);
           LandDirty[t div 32, i div 32]:= 1;
           end;

t:= y - dx;
if (t and LAND_HEIGHT_MASK) = 0 then
   for i:= Max(x - dy, 0) to Min(x + dy, LAND_WIDTH - 1) do
       if ((Land[t, i] and lfBasic) <> 0) or ((Land[t, i] and lfObject) <> 0) then
          begin
           if (cReducedQuality and rqBlurryLand) = 0 then
          LandPixels[t, i]:= cExplosionBorderColor
            else
          LandPixels[t div 2, i div 2]:= cExplosionBorderColor;

          Land[t, i]:= Land[t, i] or lfDamaged;
          //Despeckle(i, y - dy);
          LandDirty[t div 32, i div 32]:= 1;
          end;
end;

function DrawExplosion(X, Y, Radius: LongInt): Longword;
var dx, dy, ty, tx, d: LongInt;
    cnt: Longword;
begin

// draw background land texture
    begin
    cnt:= 0;
    dx:= 0;
    dy:= Radius;
    d:= 3 - 2 * Radius;

    while (dx < dy) do
        begin
        inc(cnt, FillLandCircleLinesBG(x, y, dx, dy));
        if (d < 0)
        then d:= d + 4 * dx + 6
        else begin
            d:= d + 4 * (dx - dy) + 10;
            dec(dy)
            end;
        inc(dx)
        end;
    if (dx = dy) then inc(cnt, FillLandCircleLinesBG(x, y, dx, dy));
    end;

// draw a hole in land
if Radius > 20 then
    begin
    dx:= 0;
    dy:= Radius - 15;
    d:= 3 - 2 * dy;

    while (dx < dy) do
        begin
        FillLandCircleLines0(x, y, dx, dy);
        if (d < 0)
        then d:= d + 4 * dx + 6
        else begin
            d:= d + 4 * (dx - dy) + 10;
            dec(dy)
            end;
        inc(dx)
        end;
    if (dx = dy) then FillLandCircleLines0(x, y, dx, dy);
    end;

  // FillRoundInLand after erasing land pixels to allow Land 0 check for mask.png to function
    FillRoundInLand(X, Y, Radius, 0);

// draw explosion border
    begin
    inc(Radius, 4);
    dx:= 0;
    dy:= Radius;
    d:= 3 - 2 * Radius;
    while (dx < dy) do
        begin
        FillLandCircleLinesEBC(x, y, dx, dy);
        if (d < 0)
        then d:= d + 4 * dx + 6
        else begin
            d:= d + 4 * (dx - dy) + 10;
            dec(dy)
            end;
        inc(dx)
        end;
    if (dx = dy) then FillLandCircleLinesEBC(x, y, dx, dy);
    end;

tx:= Max(X - Radius - 1, 0);
dx:= Min(X + Radius + 1, LAND_WIDTH) - tx;
ty:= Max(Y - Radius - 1, 0);
dy:= Min(Y + Radius + 1, LAND_HEIGHT) - ty;
UpdateLandTexture(tx, dx, ty, dy);
DrawExplosion:= cnt
end;

procedure DrawHLinesExplosions(ar: PRangeArray; Radius: LongInt; y, dY: LongInt; Count: Byte);
var tx, ty, i: LongInt;
begin
for i:= 0 to Pred(Count) do
    begin
    for ty:= Max(y - Radius, 0) to Min(y + Radius, LAND_HEIGHT) do
        for tx:= Max(0, ar^[i].Left - Radius) to Min(LAND_WIDTH, ar^[i].Right + Radius) do
            if ((Land[ty, tx] and lfBasic) <> 0) and not disableLandBack then
                if (cReducedQuality and rqBlurryLand) = 0 then
                    LandPixels[ty, tx]:= LandBackPixel(tx, ty)
                else
                    LandPixels[ty div 2, tx div 2]:= LandBackPixel(tx, ty)
            else
                if ((Land[ty, tx] and lfObject) <> 0) or (disableLandBack and ((Land[ty, tx] and lfIndestructible) = 0)) then
                    if (cReducedQuality and rqBlurryLand) = 0 then
                        LandPixels[ty, tx]:= 0
                    else
                        LandPixels[ty div 2, tx div 2]:= 0;
    inc(y, dY)
    end;

inc(Radius, 4);
dec(y, Count * dY);

for i:= 0 to Pred(Count) do
    begin
    for ty:= Max(y - Radius, 0) to Min(y + Radius, LAND_HEIGHT) do
        for tx:= Max(0, ar^[i].Left - Radius) to Min(LAND_WIDTH, ar^[i].Right + Radius) do
            if ((Land[ty, tx] and lfBasic) <> 0) or ((Land[ty, tx] and lfObject) <> 0) then
                begin
                    if (cReducedQuality and rqBlurryLand) = 0 then
                        LandPixels[ty, tx]:= cExplosionBorderColor
                    else
                        LandPixels[ty div 2, tx div 2]:= cExplosionBorderColor;

                Land[ty, tx]:= Land[ty, tx] or lfDamaged;
                LandDirty[ty div 32, tx div 32]:= 1;
                end;
    inc(y, dY)
    end;


UpdateLandTexture(0, LAND_WIDTH, 0, LAND_HEIGHT)
end;

//
//  - (dX, dY) - direction, vector of length = 0.5
//
procedure DrawTunnel(X, Y, dX, dY: hwFloat; ticks, HalfWidth: LongInt);
var nx, ny, dX8, dY8: hwFloat;
    i, t, tx, ty, stX, stY, ddy, ddx: Longint;
begin  // (-dY, dX) is (dX, dY) rotated by PI/2
stY:= hwRound(Y);
stX:= hwRound(X);

nx:= X + dY * (HalfWidth + 8);
ny:= Y - dX * (HalfWidth + 8);

dX8:= dX * 8;
dY8:= dY * 8;
for i:= 0 to 7 do
    begin
    X:= nx - dX8;
    Y:= ny - dY8;
    for t:= -8 to ticks + 8 do
    begin
    X:= X + dX;
    Y:= Y + dY;
    tx:= hwRound(X);
    ty:= hwRound(Y);
    if ((ty and LAND_HEIGHT_MASK) = 0) and
       ((tx and LAND_WIDTH_MASK) = 0) and
       (((Land[ty, tx] and lfBasic) <> 0) or
       ((Land[ty, tx] and lfObject) <> 0)) then
        begin
        Land[ty, tx]:= Land[ty, tx] or lfDamaged;
            if (cReducedQuality and rqBlurryLand) = 0 then
            LandPixels[ty, tx]:= cExplosionBorderColor
            else
            LandPixels[ty div 2, tx div 2]:= cExplosionBorderColor
        end
    end;
    nx:= nx - dY;
    ny:= ny + dX;
    end;

for i:= -HalfWidth to HalfWidth do
    begin
    X:= nx - dX8;
    Y:= ny - dY8;
    for t:= 0 to 7 do
    begin
    X:= X + dX;
    Y:= Y + dY;
    tx:= hwRound(X);
    ty:= hwRound(Y);
    if ((ty and LAND_HEIGHT_MASK) = 0) and
       ((tx and LAND_WIDTH_MASK) = 0) and
       (((Land[ty, tx] and lfBasic) <> 0) or
       ((Land[ty, tx] and lfObject) <> 0)) then
        begin
        Land[ty, tx]:= Land[ty, tx] or lfDamaged;
            if (cReducedQuality and rqBlurryLand) = 0 then
        LandPixels[ty, tx]:= cExplosionBorderColor
            else
        LandPixels[ty div 2, tx div 2]:= cExplosionBorderColor

        end
    end;
    X:= nx;
    Y:= ny;
    for t:= 0 to ticks do
        begin
        X:= X + dX;
        Y:= Y + dY;
        tx:= hwRound(X);
        ty:= hwRound(Y);
        if ((ty and LAND_HEIGHT_MASK) = 0) and ((tx and LAND_WIDTH_MASK) = 0) and ((Land[ty, tx] and lfIndestructible) = 0) then
            begin
            if ((Land[ty, tx] and lfBasic) <> 0) and not disableLandBack then
                if (cReducedQuality and rqBlurryLand) = 0 then
                    LandPixels[ty, tx]:= LandBackPixel(tx, ty)
                else
                    LandPixels[ty div 2, tx div 2]:= LandBackPixel(tx, ty)
            else
              if ((Land[ty, tx] and lfObject) <> 0) or (disableLandBack and ((Land[ty, tx] and lfIndestructible) = 0)) then
                if (cReducedQuality and rqBlurryLand) = 0 then
                LandPixels[ty, tx]:= 0
                else
                LandPixels[ty div 2, tx div 2]:= 0;

            Land[ty, tx]:= 0;
            end
        end;
    for t:= 0 to 7 do
    begin
    X:= X + dX;
    Y:= Y + dY;
    tx:= hwRound(X);
    ty:= hwRound(Y);
    if ((ty and LAND_HEIGHT_MASK) = 0) and
       ((tx and LAND_WIDTH_MASK) = 0) and
       (((Land[ty, tx] and lfBasic) <> 0) or
       ((Land[ty, tx] and lfObject) <> 0)) then
        begin
        Land[ty, tx]:= Land[ty, tx] or lfDamaged;
        if (cReducedQuality and rqBlurryLand) = 0 then
        LandPixels[ty, tx]:= cExplosionBorderColor
        else
        LandPixels[ty div 2, tx div 2]:= cExplosionBorderColor

        end
    end;
    nx:= nx - dY;
    ny:= ny + dX;
    end;

for i:= 0 to 7 do
    begin
    X:= nx - dX8;
    Y:= ny - dY8;
    for t:= -8 to ticks + 8 do
    begin
    X:= X + dX;
    Y:= Y + dY;
    tx:= hwRound(X);
    ty:= hwRound(Y);
    if ((ty and LAND_HEIGHT_MASK) = 0) and
       ((tx and LAND_WIDTH_MASK) = 0) and
       (((Land[ty, tx] and lfBasic) <> 0) or
       ((Land[ty, tx] and lfObject) <> 0)) then
        begin
        Land[ty, tx]:= Land[ty, tx] or lfDamaged;
        if (cReducedQuality and rqBlurryLand) = 0 then
        LandPixels[ty, tx]:= cExplosionBorderColor
        else
        LandPixels[ty div 2, tx div 2]:= cExplosionBorderColor
        end
    end;
    nx:= nx - dY;
    ny:= ny + dX;
    end;

tx:= Max(stX - HalfWidth * 2 - 4 - abs(hwRound(dX * ticks)), 0);
ty:= Max(stY - HalfWidth * 2 - 4 - abs(hwRound(dY * ticks)), 0);
ddx:= Min(stX + HalfWidth * 2 + 4 + abs(hwRound(dX * ticks)), LAND_WIDTH) - tx;
ddy:= Min(stY + HalfWidth * 2 + 4 + abs(hwRound(dY * ticks)), LAND_HEIGHT) - ty;

UpdateLandTexture(tx, ddx, ty, ddy)
end;

function TryPlaceOnLand(cpX, cpY: LongInt; Obj: TSprite; Frame: LongInt; doPlace: boolean; indestructible: boolean): boolean;
var X, Y, bpp, h, w, row, col, numFramesFirstCol: LongInt;
    p: PByteArray;
    Image: PSDL_Surface;
begin
numFramesFirstCol:= SpritesData[Obj].imageHeight div SpritesData[Obj].Height;

TryDo(SpritesData[Obj].Surface <> nil, 'Assert SpritesData[Obj].Surface failed', true);
Image:= SpritesData[Obj].Surface;
w:= SpritesData[Obj].Width;
h:= SpritesData[Obj].Height;
row:= Frame mod numFramesFirstCol;
col:= Frame div numFramesFirstCol;

if SDL_MustLock(Image) then
   SDLTry(SDL_LockSurface(Image) >= 0, true);

bpp:= Image^.format^.BytesPerPixel;
TryDo(bpp = 4, 'It should be 32 bpp sprite', true);
// Check that sprite fits free space
p:= @(PByteArray(Image^.pixels)^[ Image^.pitch * row * h + col * w * 4 ]);
case bpp of
     4: for y:= 0 to Pred(h) do
            begin
            for x:= 0 to Pred(w) do
                if PLongword(@(p^[x * 4]))^ <> 0 then
                   if ((cpY + y) <= Longint(topY)) or
                      ((cpY + y) >= LAND_HEIGHT) or
                      ((cpX + x) <= Longint(leftX)) or
                      ((cpX + x) >= Longint(rightX)) or
                      (Land[cpY + y, cpX + x] <> 0) then
                      begin
                      if SDL_MustLock(Image) then
                         SDL_UnlockSurface(Image);
                      exit(false)
                      end;
            p:= @(p^[Image^.pitch]);
            end;
     end;

TryPlaceOnLand:= true;
if not doPlace then
   begin
   if SDL_MustLock(Image) then
      SDL_UnlockSurface(Image);
   exit
   end;

// Checked, now place
p:= @(PByteArray(Image^.pixels)^[ Image^.pitch * row * h + col * w * 4 ]);
case bpp of
     4: for y:= 0 to Pred(h) do
            begin
            for x:= 0 to Pred(w) do
                if PLongword(@(p^[x * 4]))^ <> 0 then
                   begin
                   if indestructible then
                       Land[cpY + y, cpX + x]:= lfIndestructible
                   else
                       Land[cpY + y, cpX + x]:= lfObject;
                   if (cReducedQuality and rqBlurryLand) = 0 then
                       LandPixels[cpY + y, cpX + x]:= PLongword(@(p^[x * 4]))^
                   else
                       LandPixels[(cpY + y) div 2, (cpX + x) div 2]:= PLongword(@(p^[x * 4]))^
                   end;
            p:= @(p^[Image^.pitch]);
            end;
     end;
if SDL_MustLock(Image) then
   SDL_UnlockSurface(Image);

x:= Max(cpX, leftX);
w:= Min(cpX + Image^.w, LAND_WIDTH) - x;
y:= Max(cpY, topY);
h:= Min(cpY + Image^.h, LAND_HEIGHT) - y;
UpdateLandTexture(x, w, y, h)
end;

// was experimenting with applying as damage occurred.
function Despeckle(X, Y: LongInt): boolean;
var nx, ny, i, j, c, xx, yy: LongInt;
    pixelsweep: boolean;
begin
if (cReducedQuality and rqBlurryLand) = 0 then
   begin
   xx:= X;
   yy:= Y;
   end
else
   begin
   xx:= X div 2;
   yy:= Y div 2;
   end;
pixelsweep:= ((Land[Y, X] and $FF00) = 0) and (LandPixels[yy, xx] <> 0);
if (((Land[Y, X] and lfDamaged) <> 0) and ((Land[Y, X] and lfIndestructible) = 0)) or pixelsweep then
    begin
    c:= 0;
    for i:= -1 to 1 do
        for j:= -1 to 1 do
            if (i <> 0) or (j <> 0) then
                begin
                ny:= Y + i;
                nx:= X + j;
                if ((ny and LAND_HEIGHT_MASK) = 0) and ((nx and LAND_WIDTH_MASK) = 0) then
                    begin
                    if pixelsweep then
                        begin
                        if ((cReducedQuality and rqBlurryLand) <> 0) then
                            begin
                            nx:= nx div 2;
                            ny:= ny div 2
                            end;
                        if LandPixels[ny, nx] <> 0 then inc(c);
                        end
                    else if Land[ny, nx] > 255 then inc(c);
                    end
                end;

    if c < 4 then // 0-3 neighbours
        begin
        if ((Land[Y, X] and lfBasic) <> 0) and not disableLandBack then
            LandPixels[yy, xx]:= LandBackPixel(X, Y)
        else
            LandPixels[yy, xx]:= 0;

        Land[Y, X]:= 0;
        if not pixelsweep then exit(true);
        end;
    end;
Despeckle:= false
end;

function SweepDirty: boolean;
var x, y, xx, yy, ty, tx: LongInt;
    bRes, updateBlock, resweep, recheck: boolean;
begin
bRes:= false;
reCheck:= true;

while recheck do
    begin
    recheck:= false;
    for y:= 0 to LAND_HEIGHT div 32 - 1 do
        begin
        for x:= 0 to LAND_WIDTH div 32 - 1 do
            begin
            if LandDirty[y, x] <> 0 then
                begin
                updateBlock:= false;
                resweep:= true;
                ty:= y * 32;
                tx:= x * 32;
                while(resweep) do
                    begin
                    resweep:= false;
                    for yy:= ty to ty + 31 do
                        for xx:= tx to tx + 31 do
                            if Despeckle(xx, yy) then
                                begin
                                bRes:= true;
                                updateBlock:= true;
                                resweep:= true;
                                if (yy = ty) and (y > 0) then
                                    begin
                                    LandDirty[y-1, x]:= 1;
                                    recheck:= true;
                                    end
                                else if (yy = ty+31) and (y < LAND_HEIGHT div 32 - 1) then
                                    begin
                                    LandDirty[y+1, x]:= 1;
                                    recheck:= true;
                                    end;
                                if (xx = tx) and (x > 0) then
                                    begin
                                    LandDirty[y, x-1]:= 1;
                                    recheck:= true;
                                    end
                                else if (xx = tx+31) and (x < LAND_WIDTH div 32 - 1) then
                                    begin
                                    LandDirty[y, x+1]:= 1;
                                    recheck:= true;
                                    end
                                end;
                    end;
                if updateBlock then UpdateLandTexture(tx, 32, ty, 32);
                LandDirty[y, x]:= 0;
                end;
            end;
        end;
     end;

SweepDirty:= bRes;
end;

// Return true if outside of land or not the value tested, used right now for some X/Y movement that does not use normal hedgehog movement in GSHandlers.inc
function CheckLandValue(X, Y: LongInt; LandFlag: Word): boolean;
begin
     CheckLandValue:= ((X and LAND_WIDTH_MASK <> 0) or (Y and LAND_HEIGHT_MASK <> 0)) or ((Land[Y, X] and LandFlag) = 0)
end;

function LandBackPixel(x, y: LongInt): LongWord;
var p: PLongWordArray;
begin
    if LandBackSurface = nil then LandBackPixel:= 0
    else
    begin
        p:= LandBackSurface^.pixels;
        LandBackPixel:= p^[LandBackSurface^.w * (y mod LandBackSurface^.h) + (x mod LandBackSurface^.w)];// or $FF000000;
    end
end;


end.
