//+------------------------------------------------------------------+
//|                                                          RBO.mq5 |
//|                                Copyright 2024, EN3 Technologies. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, EN3 Technologies."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade/Trade.mqh>

CTrade trade;

input string RangeTimeStart = "5:00";
input string RangeTimeEnd = "10:00";
input string endTradeTime = "23:00";
input long Magic = 333;

bool endOfRange = false;
bool rangeStarted = false;
bool allowTrades = false;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double highestPricePoint = NormalizeDouble(0, _Digits);
double lowestPricePoint = NormalizeDouble(-1, _Digits);

int barsSinceStartOfRange = 0;
int rectCount = 0;
int totalOrdersPlacedForTheDay;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   trade.SetExpertMagicNumber(Magic);
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {

  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
bool allowBuyStop = false;
bool allowSellStop = false;
void OnTick()
  {
   datetime currentBarOpeningTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   string time = TimeToString(currentBarOpeningTime, TIME_MINUTES);

   if(rangeStarted)
     {
      totalOrdersPlacedForTheDay = 0;
      //initialize lowest and highest price points @ the beg of range:
      int firstBarIndex = iBarShift(_Symbol, PERIOD_CURRENT, StringToTime(RangeTimeStart), true);
      if(firstBarIndex == 0)
        {
         highestPricePoint = iHigh(_Symbol, PERIOD_CURRENT, firstBarIndex);
         lowestPricePoint = iLow(_Symbol, PERIOD_CURRENT, firstBarIndex);
        }


      drawRangeRect(ChartID(), "RangeRectangle" + IntegerToString(rectCount), StringToTime(RangeTimeStart),
                    lowestPricePoint, StringToTime(RangeTimeEnd), highestPricePoint);

      //detect a change in the number of bars;
      if(Bars(_Symbol, PERIOD_CURRENT, StringToTime(RangeTimeStart), StringToTime(RangeTimeEnd)) >
         barsSinceStartOfRange)
        {
         barsSinceStartOfRange = Bars(_Symbol, PERIOD_CURRENT, StringToTime(RangeTimeStart),
                                      StringToTime(RangeTimeEnd));
         int prevBarHigh = iHighest(_Symbol, PERIOD_CURRENT, MODE_HIGH, barsSinceStartOfRange, 1);
         int prevBarLow = iLowest(_Symbol, PERIOD_CURRENT, MODE_LOW, barsSinceStartOfRange, 1);

         double prevBarHighPrice = iHigh(_Symbol, PERIOD_CURRENT, prevBarHigh);
         double prevBarLowPrice = iLow(_Symbol, PERIOD_CURRENT, prevBarLow);

         if(prevBarHighPrice > highestPricePoint)
           {
            highestPricePoint = prevBarHighPrice;
           }
         if(prevBarLowPrice < lowestPricePoint)
           {
            lowestPricePoint = prevBarLowPrice;
           }
        }

     }
   else
     {
      if(RangeTimeStart == time)
        {
         rangeStarted = true;
         allowTrades = true;
         endOfRange = false;
        }
     }


   if(!endOfRange)
     {
      if(RangeTimeEnd == time)
        {
         allowBuyStop = true;
         allowSellStop = true;
         rangeStarted = false;
         endOfRange = true;
         rectCount++;
         //reset lowest and highest price points;
         int firstBarIndex = iBarShift(_Symbol, PERIOD_CURRENT, StringToTime(RangeTimeStart), true);
         //reset bars;
         barsSinceStartOfRange = 0;
        }
     }
   else
     {
      int activePositions = checkActivePositionsByEA();
      int orders = checkOrdersByEA();
      
      if(time == endTradeTime)
        {
        Print("Time to close all opeations");
         closePositionsAndOrders();
         allowTrades = false;
        }

      if(allowTrades)
        {
         if(orders <= 1)
           {
            if(allowBuyStop)
              {
               trade.BuyStop(1, highestPricePoint, _Symbol, lowestPricePoint);
               totalOrdersPlacedForTheDay++;
               allowBuyStop = false;
              }
            if(allowSellStop)
              {
               trade.SellStop(1, lowestPricePoint, _Symbol, highestPricePoint);
               totalOrdersPlacedForTheDay++;
               allowSellStop = false;
              }
           }
        }
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int checkActivePositionsByEA()
  {
   int totalActivePostions = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong positionTicket = PositionGetTicket(i);
      long positionMagic = PositionGetInteger(POSITION_MAGIC);

      if(positionMagic == Magic)
         totalActivePostions++;
     }
   return totalActivePostions;
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int checkOrdersByEA()
  {
   int totalOrders = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      ulong orderTicket = OrderGetTicket(i);
      long orderMagic = OrderGetInteger(ORDER_MAGIC);
      if(orderMagic == Magic)
         totalOrders++;
     }
   return totalOrders;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void closePositionsAndOrders()
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong positionTicket = PositionGetTicket(i);
      long positionMagic = PositionGetInteger(POSITION_MAGIC);
      if(positionMagic == Magic)
         trade.PositionClose(positionTicket);
     }

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      ulong orderTicket = OrderGetTicket(i);
      long orderMagic = OrderGetInteger(ORDER_MAGIC);
      if(orderMagic == Magic)
         trade.OrderDelete(orderTicket);
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void drawRangeRect(long chartID, string name, datetime rangeStartTime,
                   double lowPrice, datetime rangeEndtime, double highPrice)
  {
   ENUM_OBJECT objectType = OBJ_RECTANGLE;
   bool objCreated = ObjectCreate(chartID, name,
                                  objectType,
                                  0,// window index
                                  rangeStartTime,
                                  lowPrice,
                                  rangeEndtime,
                                  highPrice
                                 );

   ObjectSetInteger(chartID,name,OBJPROP_COLOR,clrCornflowerBlue);
//--- set the style of rectangle lines
   ObjectSetInteger(chartID,name,OBJPROP_STYLE,STYLE_SOLID);
//--- set width of the rectangle lines
   ObjectSetInteger(chartID,name,OBJPROP_WIDTH,1);
//--- enable (true) or disable (false) the mode of filling the rectangle
   ObjectSetInteger(chartID,name,OBJPROP_FILL,true);
//--- display in the foreground (false) or background (true)
   ObjectSetInteger(chartID,name,OBJPROP_BACK,true);
//--- enable (true) or disable (false) the mode of highlighting the rectangle for moving
//--- when creating a graphical object using ObjectCreate function, the object cannot be
//--- highlighted and moved by default. Inside this method, selection parameter
//--- is true by default making it possible to highlight and move the object
   ObjectSetInteger(chartID,name,OBJPROP_SELECTABLE,true);
   ObjectSetInteger(chartID,name,OBJPROP_SELECTED,false);
//--- hide (true) or display (false) graphical object name in the object list
   ObjectSetInteger(chartID,name,OBJPROP_HIDDEN,false);
//--- set the priority for receiving the event of a mouse click in the chart
   ObjectSetInteger(chartID,name,OBJPROP_ZORDER,0);
  }

/*


   #BUGS:
   * We have a limit of 2 orders, when one gets activated, we have a total of 1
   which passes the <= 1 check, causing the program to place another order when target level is touched.
      Possible solutions:
         1. As soon as we place the orders, we can nullify the highest and lowest price points, add a check
            of !null before we can place orders
         2. Add a global count variable that keeps track of the orders for the day.
         
         
         
   RStart (00:00)
      (work/tasks to be run within the range)
      Highest and Lowest Point to be updated with every tick

      if current bar is the first bar of the day (bar @ 0:00), initialize highest and lowest price points;
      if current bar is not the first bar of the day (any other time within the range) use the previous bar's
         highest and lowest price points if
            if it's high is higher than the current highest value set;
            if it's low is lower than the current lowest value set;
         continue this while we are within the range;
   REnd (07:00)

   TradingPeriod: (7:00)
      (work/tasks to be run within the trading period)
      #Regularly:
      - check # of Orders (Buy and Sell Stops)
      - check # of Positions
      - how do they compare to the limits?
      - can we place orders?


      get all Orders:
         compare their magic #s
         if they match EA's magic #
            keep track of the order;

      if total orders belonging to the EA are less than the set order limit (being 2);
         place BuyStop and SellStop orders @ highest Price Point and lowest Price Price point respectively;
         increase the total # of orders
         disable ability to place orders (buy and sell) until the next day;
         lowest price point and highest price points should also be used as the Stop orders' Stop Losses;


   TradingPeriodEnd: (23:00)

   PostRangeAndTradingSession (23:00 - 00:00)
      (work/tasks to be run post range and trading periods)
      - Close all active Positions and Orders;
      - Reset any variables set in the initialization stage;

      get all Positions;
      Compare their magic #s the EA's magic #
      if match;
         Close the position(s);

*/
//+------------------------------------------------------------------+
