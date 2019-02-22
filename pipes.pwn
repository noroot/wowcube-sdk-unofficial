#include "cubios_abi.pwn"

// TODO: put your Game logic here
#define PIPES_BASE 0
#define STEAM_BASE 16
#define PIPES_COUNT 16
#define STEAM_COUNT 9

new steam_draw [FACES_PER_CUBE];//Check to draw steam
new steam_frame[FACES_PER_CUBE][RIBS_PER_CUBE];//resID of steam to draw
new steam_angle[FACES_PER_CUBE];
new steam_count_base[RIBS_PER_CUBE];
new steam_x[RIBS_PER_CUBE];
new steam_y[RIBS_PER_CUBE];

new const level[PROJECTION_MAX_X][PROJECTION_MAX_Y] = [
  [ 0,  0,  0,  0,  0,  0],
  [ 0,  0, 12,  6,  0,  0],
  [ 0, 12, 15, 11,  6,  0],
  [ 0,  9, 15, 14,  3,  0],
  [ 0,  0,  9,  3,  0,  0],
  [ 0,  0,  0,  0,  0,  0],
  [ 0,  0,  0,  0,  0,  0],
  [ 0,  0,  0,  0,  0,  0]
];

rotateFigureBitwise(figure, angle)
{
  new r = figure;

  switch(angle)
  {
    case  -90: { r = ((figure >> 1) & 0x7) | ((figure << 3) & 0x8); } // 90
    case -180: { r = ((figure >> 2) & 0x3) | ((figure << 2) & 0xC); } // 180
    case -270: { r = ((figure >> 3) & 0x1) | ((figure << 1) & 0xE); } // 270
    case   90: { r = ((figure << 1) & 0xE) | ((figure >> 3) & 0x1); } // -90
    case  180: { r = ((figure << 2) & 0xC) | ((figure >> 2) & 0x3); } // -180
    case  270: { r = ((figure << 3) & 0x8) | ((figure >> 1) & 0x7); } // -270
  }
  return r;
}
rotateFigureBitwisePipes(figure, angle)
{
  new r = figure;

  switch(angle)
  {
    case  -90: { r = ((figure << 3) & 0xF) | (figure >> 1 & 0xF); } // 90
    case -180: { r = ((figure << 2) & 0xF) | (figure >> 2 & 0xF); } // 180
    case -270: { r = ((figure << 1) & 0xF) | (figure >> 3 & 0xF); } // 270
    case   90: { r = ((figure << 1) & 0xF) | (figure >> 3 & 0xF); } // -90
    case  180: { r = ((figure << 2) & 0xF) | (figure >> 2 & 0xF); } // -180
    case  270: { r = ((figure << 3) & 0xF) | (figure >> 1 & 0xF); } // -270
  }
  return r;
}

drawInterPipesConnector(x, y, _resID)
{
  new resID = rotateFigureBitwise(_resID, abi_pam[x][y]);
  //new cubeN = abi_pm[x][y][0];
  new faceN = abi_pm[x][y][1];

  switch(resID)
  {
    case 8: { abi_CMD_BITMAP(faceN, resID, 240/2-120/2, 0); } // top 1000
    case 4: { abi_CMD_BITMAP(faceN, resID, 240-32, 240/2-120/2); } // right 0100
    case 2: { abi_CMD_BITMAP(faceN, resID, 240/2-120/2, 240-32); } // bottom 0010
    case 1: { abi_CMD_BITMAP(faceN, resID, 0, 240/2-120/2); } // left 0001
  }
}
isFace(x, y) // is face in Projection Matrix is out-of-bound or empty field or normal cube's face
{
  if((x < 0) || (x >= PROJECTION_MAX_X)) return 0;
  if((y < 0) || (y >= PROJECTION_MAX_Y)) return 0;
  if((abi_pm[x][y][0] == 0xFF) || (abi_pm[x][y][1] == 0xFF)) return 0;
  return 1;
}

hasTopPipe(figure)
{
  return ((figure >> 3) & 0x1);
}

hasRightPipe(figure)
{
  return ((figure >> 2) & 0x1);
}

hasBottomPipe(figure)
{
  return ((figure >> 1) & 0x1);
}

hasLeftPipe(figure)
{
  return ((figure >> 0) & 0x1);
}
onCubeAttach()
{
  new cubeN = 0;
  new faceN = 0;
  new x = 0; // projection X
  new y = 0; // projection Y
  new a = 0; // projection Angle (face rotated at)
  new a_real = 0;
  new x_real = 0;
  new y_real = 0; //for real angle
  new pipesResIDRotated[CUBES_MAX][FACES_PER_CUBE]; // Game Field
  new pipesResIDRotatedForPipes[CUBES_MAX][FACES_PER_CUBE]; // Game Field
  new pipesResIDOriginal[CUBES_MAX][FACES_PER_CUBE];
  new thisFigure = 0;
  new compareFigure = 0;
  // I know that calculate all the game field is quite NOT RATIONAL :(
  for(cubeN=0; cubeN<CUBES_MAX; cubeN++)
  {
    //printf("CubeN=%d\n",cubeN);
    for(faceN=0; faceN<FACES_PER_CUBE; faceN++)
    {
      // calculate faces and rotated bitmaps positions
      abi_InitialFacePositionAtProjection(cubeN, faceN, x, y, a);
      pipesResIDOriginal[cubeN][faceN] = level[x][y];
      pipesResIDRotated[cubeN][faceN] = rotateFigureBitwise(level[x][y], a);
      abi_FacePositionAtProjection(cubeN, faceN, x_real, y_real, a_real);
      pipesResIDRotatedForPipes[cubeN][faceN] = rotateFigureBitwisePipes(level[x][y], a-a_real);
      if (cubeN==abi_cubeN)
	steam_angle[faceN]=a_real;
    }
  }
  // Draw a part of level on this cube's face 0-2
  for(faceN=0; faceN<FACES_PER_CUBE; faceN++)
  {
    steam_draw[faceN]=0;
    abi_CMD_BITMAP(faceN, pipesResIDRotated[abi_cubeN][faceN], 0, 0);
  }
  // Check if top or right neighbors are connected
  for(x=0; x<PROJECTION_MAX_X; x++)
  {
    for(y=0; y<PROJECTION_MAX_Y; y++)
    {
      if(abi_pm[x][y][0] != abi_cubeN) continue; // for this cube only!
      //if(0 == isFace(x, y)) continue; // no cube/face at this position matrix position!
      thisFigure = pipesResIDRotatedForPipes[abi_pm[x][y][0]][abi_pm[x][y][1]];

      if (isFace(x, y))
      {
	if((x==0 || !isFace(x-1,y)) && hasLeftPipe(thisFigure)) drawInterPipesConnector(x, y, 1);
	if((y==0 || !isFace(x,y-1)) && hasBottomPipe(thisFigure)) drawInterPipesConnector(x, y, 2);
      }
      //Check compare figure, but draw only on this cube
      if (isFace(x,y))
      {
	if (isFace(x,y+1))//Check Top figure
	{
	  compareFigure = pipesResIDRotatedForPipes[abi_pm[x][y+1][0]][abi_pm[x][y+1][1]];
	  if (hasTopPipe(thisFigure) && (hasBottomPipe(compareFigure)))
	    drawInterPipesConnector(x, y, 8); // 1000 = 8 = top pipe connector
	  if (!hasTopPipe(thisFigure) && (hasBottomPipe(compareFigure)))
	    steam_draw[abi_pm[x][y][1]]+=8;
	}
	else
	{
	  if (hasTopPipe(thisFigure))
	    drawInterPipesConnector(x, y, 8); // 1000 = 8 = top pipe connector
	}

	if (y>0 && isFace(x,y-1))//Check Bottom figure
	{
	  compareFigure = pipesResIDRotatedForPipes[abi_pm[x][y-1][0]][abi_pm[x][y-1][1]];
	  if (hasBottomPipe(thisFigure) && (hasTopPipe(compareFigure)))
	    drawInterPipesConnector(x, y, 2); // 0010 = 2 = bottom pipe connector
	  if (!hasBottomPipe(thisFigure) && (hasTopPipe(compareFigure)))
	    steam_draw[abi_pm[x][y][1]]+=2;
	}
	if (isFace(x+1,y))//Check Right figure
	{
	  compareFigure = pipesResIDRotatedForPipes[abi_pm[x+1][y][0]][abi_pm[x+1][y][1]];
	  if (hasRightPipe(thisFigure) && hasLeftPipe(compareFigure))
	    drawInterPipesConnector(x,y,4); // 0100 = 4 = rigth pipe connector
	  if (!hasRightPipe(thisFigure) && hasLeftPipe(compareFigure))
	    steam_draw[abi_pm[x][y][1]]+=4;
	}
	else
	{
	  if (hasRightPipe(thisFigure))
	    drawInterPipesConnector(x,y,4); // 0100 = 4 = rigth pipe connector
	}
	if (x>0 && isFace(x-1,y))//Check Left figure
	{
	  compareFigure = pipesResIDRotatedForPipes[abi_pm[x-1][y][0]][abi_pm[x-1][y][1]];
	  if (hasLeftPipe(thisFigure) && (hasRightPipe(compareFigure)))
	    drawInterPipesConnector(x, y, 1); // 0001 = 1 = left pipe connector
	  if (!hasLeftPipe(thisFigure) && (hasRightPipe(compareFigure)))
	    steam_draw[abi_pm[x][y][1]]+=1;
	}
      }
      /*
      thisFigure = pipesResIDRotated[abi_pm[x][y][0]][abi_pm[x][y][1]];
      //We test the drawing of all connectors. What are all the angles we got the right.
      if (isFace(x,y))
      {
	if (hasRightPipe(thisFigure))
	  drawInterPipesConnector(x, y, 4); // 0100 = 4 = right pipe connector
	if (hasLeftPipe(thisFigure))
	  drawInterPipesConnector(x, y, 1); // 0100 = 4 = right pipe connector
	if (hasTopPipe(thisFigure))
	  drawInterPipesConnector(x, y, 8); // 0100 = 4 = right pipe connector
	if (hasBottomPipe(thisFigure))
	  drawInterPipesConnector(x, y, 2); // 0100 = 4 = right pipe connector
      }/**/
    }
  }
}
drawSteam()
{
  for(new faceN=0; faceN<FACES_PER_CUBE; faceN++)
  {

    for(new ribN=0; ribN<RIBS_PER_CUBE; ribN++)
    {
      if (steam_frame[faceN][ribN]==STEAM_COUNT)
	steam_frame[faceN][ribN]=0;
      if (steam_frame[faceN][ribN]==0 && hasSteam(steam_draw[faceN],ribN))
	steam_frame[faceN][ribN]=1;
      if (steam_frame[faceN][ribN]==5 && hasSteam(steam_draw[faceN],ribN))
	steam_frame[faceN][ribN]=3;
      steam_count_base[ribN]=ribN;

      if (ribN==0)
	switch(steam_angle[faceN])
	{
	  case 270: {steam_count_base[ribN]=3; steam_x[ribN]=240/2-120/2; steam_y[ribN]=0;}
	  case 180: {steam_count_base[ribN]=0; steam_x[ribN]=0; steam_y[ribN]=0;}
	  case  90: {steam_count_base[ribN]=1; steam_x[ribN]=0; steam_y[ribN]=0;}
	  case   0: {steam_count_base[ribN]=2; steam_x[ribN]=0; steam_y[ribN]=120/2;}
	}
      if (ribN==1)
	switch(steam_angle[faceN])
	{
	  case 270: {steam_count_base[ribN]=2; steam_x[ribN]=0; steam_y[ribN]=120/2;}
	  case 180: {steam_count_base[ribN]=3; steam_x[ribN]=120/2; steam_y[ribN]=0;}
	  case  90: {steam_count_base[ribN]=0; steam_x[ribN]=0; steam_y[ribN]=0;}
	  case   0: {steam_count_base[ribN]=1; steam_x[ribN]=0; steam_y[ribN]=0;}
	}
      if (ribN==2)
	switch(steam_angle[faceN])
	{
	  case 270: {steam_count_base[ribN]=1; steam_x[ribN]=0; steam_y[ribN]=0;}
	  case 180: {steam_count_base[ribN]=2; steam_x[ribN]=0; steam_y[ribN]=120/2;}
	  case  90: {steam_count_base[ribN]=3; steam_x[ribN]=240/2-120/2; steam_y[ribN]=0;}
	  case   0: {steam_count_base[ribN]=0; steam_x[ribN]=0; steam_y[ribN]=0;}
	}
      if (ribN==3)
	switch(steam_angle[faceN])
	{
	  case 270: {steam_count_base[ribN]=0; steam_x[ribN]=0; steam_y[ribN]=0;}
	  case 180: {steam_count_base[ribN]=1; steam_x[ribN]=0; steam_y[ribN]=0;}
	  case  90: {steam_count_base[ribN]=2; steam_x[ribN]=0; steam_y[ribN]=240/2-120/2;}
	  case   0: {steam_count_base[ribN]=3; steam_x[ribN]=120/2; steam_y[ribN]=0;}
	}
      if (steam_frame[faceN][ribN]>0)
      {
	abi_CMD_BITMAP(faceN, STEAM_BASE + steam_count_base[ribN]*STEAM_COUNT + steam_frame[faceN][ribN], steam_x[ribN], steam_y[ribN]);
	steam_frame[faceN][ribN]++;
      }
    }
  }
}

hasSteam(figure, shift)
{
  return((figure >> shift) & 0x1);
}
onTick()
{
  onCubeAttach();
  drawSteam();
}

onCubeDetach()
{
  //abi_CMD_FILL(0,255,0,0);
  //abi_CMD_FILL(1,0,255,0);
  //abi_CMD_FILL(2,0,0,255);
  for(new faceN=0; faceN<FACES_PER_CUBE; faceN++)
    steam_draw[faceN]=0;
}

run(const pkt[], size, const src[])
{
  //abi_LogRcvPkt(pkt, size, src); // debug

  switch(abi_GetPktByte(pkt, 0))
  {
    case CMD_PAWN_DEBUG:
    {
      printf("[%s] CMD_PAWN_DEBUG\n", src);
    }

    case CMD_TICK:
    {
      //printf("[%s] CMD_TICK\n", src);
      onTick();
    }

    case CMD_ATTACH:
    {
      printf("[%s] CMD_ATTACH\n", src);
      abi_attached = 1;
      abi_DeserializePositonsMatrix(pkt);
      abi_LogPositionsMatrix(); // DEBUG
      onCubeAttach();
      printf("Draw0=%d Draw1=%d Draw2=%d",steam_draw[0],steam_draw[1],steam_draw[2]);
    }

    case CMD_DETACH:
    {
      printf("[%s] CMD_DETACH\n", src);
      abi_attached = 0;
      onCubeDetach();
    }
  }
}

main()
{
  new opt{100}
  argindex(0, opt);
  abi_cubeN = strval(opt);
  printf("Cube %d logic. Listening on port: %d\n", abi_cubeN, (PAWN_PORT_BASE+abi_cubeN));
  listenport(PAWN_PORT_BASE+abi_cubeN);
}
