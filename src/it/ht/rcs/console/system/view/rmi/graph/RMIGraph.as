package it.ht.rcs.console.system.view.rmi.graph
{
	import flash.geom.Point;
	
	import it.ht.rcs.console.modem.model.Modem;
	import it.ht.rcs.console.system.view.backend.graph.renderers.DBRenderer;
	import it.ht.rcs.console.system.view.rmi.graph.renderers.ModemRenderer;
	import it.ht.rcs.console.utils.ScrollableGraph;
	
	import spark.primitives.Rect;

	public class RMIGraph extends ScrollableGraph
	{
    
		public var db:DBRenderer;
    

		public function RMIGraph()
		{
			super();
		}

    
    // ----- RENDERING -----
    
    private var bg:Rect;
		public function rebuildGraph():void
		{
			removeAllElements();

			if (db == null) return;

			addElement(db);
			for each (var mr:ModemRenderer in db.modems)
				addElement(mr);

      // The background. We need a dummy component as background for two reasons:
      // 1) it defines maximum sizes
      // 2) will react to mouse events when the user clicks "nowhere" (eg, dragging)
      var p:Point = computeSize();
      bg = new Rect();
      bg.visible = false; // No need to see it, save rendering time...
      bg.width = p.x;
      bg.height = p.y;
      bg.depth = -1000; // Very bottom layer
      addElement(bg);
        
			invalidateSize();
			invalidateDisplayList();

		}
    
    private static const HORIZONTAL_DISTANCE:int = 100;
    private static const VERTICAL_DISTANCE:int   = 30;
    private static const HORIZONTAL_PAD:int      = 40;
    private static const VERTICAL_PAD:int        = 150;
    
    private function computeSize():Point
    {
      var _width:Number = 0, _height:Number = 0;
      
      if (db != null && db.modems.length > 0) {
        
        _width = (db.modems[0].width * db.modems.length) + (HORIZONTAL_DISTANCE * (db.modems.length - 1)) + HORIZONTAL_PAD * 2;
        var modemHeight:Number = (db.modems.length > 0) ? db.modems[0].height : 0;
        _height = db.height + VERTICAL_DISTANCE + modemHeight + VERTICAL_PAD * 2;
        
      }
      
      return new Point(_width, _height);
    }
    
    override protected function measure():void
    {
      super.measure();
      var p:Point = computeSize();
      measuredWidth = measuredMinWidth = p.x;
      measuredHeight = measuredMinHeight = p.y;
    }
    
		override protected function updateDisplayList(unscaledWidth:Number, unscaledHeight:Number):void
		{

			super.updateDisplayList(unscaledWidth, unscaledHeight);

      var _width:Number = Math.max(unscaledWidth, measuredWidth);
      var _height:Number = Math.max(unscaledHeight, measuredHeight);

      var i:int = 0; // Generic loop index
      var cX:int = 0, cY:int = 0; // Generic currentX, currentY
      var offsetFromCenter:int = 0; // Generic offset
      
			graphics.lineStyle(1, 0x999999, 1, true);


      if (db != null) {

				db.move(_width / 2 - db.width / 2, VERTICAL_PAD);

				// Where to draw the first modem?
				if (db.modems != null && db.modems.length > 0) {
          
          var renderer:ModemRenderer = db.modems[0];
          offsetFromCenter = db.modems.length % 2 == 0 ?
            _width / 2 - (db.modems.length / 2 * (HORIZONTAL_DISTANCE + renderer.width)) + HORIZONTAL_DISTANCE / 2 : // Even
            _width / 2 - (Math.floor(db.modems.length / 2) * (HORIZONTAL_DISTANCE + renderer.width)) - renderer.width / 2; // Odd
				
  				// Draw modems
  				for (i = 0; i < db.modems.length; i++) {
  
            renderer = db.modems[i];
  
  					cX = offsetFromCenter + i * (HORIZONTAL_DISTANCE + renderer.width);
  					cY = VERTICAL_PAD + db.height + VERTICAL_DISTANCE;
            renderer.move(cX, cY);
  
  					graphics.moveTo(_width / 2,              VERTICAL_PAD + db.height);
            graphics.lineTo(_width / 2,              VERTICAL_PAD + db.height + VERTICAL_DISTANCE / 2);
            graphics.lineTo(cX + renderer.width / 2, VERTICAL_PAD + db.height + VERTICAL_DISTANCE / 2);
            graphics.lineTo(cX + renderer.width / 2, cY);
  
  				} // End modems
          
        }
        
			} // End db

		}

	}

}