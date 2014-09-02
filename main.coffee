#!vanilla

# Temp fix - to be done in puzlet.js.
Number.prototype.pow = (p) -> Math.pow this, p

pi = Math.PI

# work around unicode issue
char = (id, code) -> $(".#{id}").html "&#{code};"
char "deg", "deg"
char "percent", "#37"
char "equals", "#61"

class d3Object

    constructor: (id) ->
        @element = d3.select "##{id}"
        @element.selectAll("svg").remove()
        @obj = @element.append "svg"
        @initAxes()
        
    append: (obj) -> @obj.append obj
    
    initAxes: ->

class Display extends d3Object

    margin = {top: 20, right: 50, bottom: 20, left: 50}
    width = 160 - margin.left - margin.right
    height = 60 - margin.top - margin.bottom

    constructor: ->
        super "temperature"

        @obj.attr("width", width + margin.left + margin.right)
        @obj.attr("height", height + margin.top + margin.bottom)

        @dateDisp = iopctrl.segdisplay()
            .width(150)
            .digitCount(5)
            .negative(true)
            .decimals(1)
        
        @append("g")
            .attr("class", "datedisplay")
            .call(@dateDisp)
        
    val: (val) -> @dateDisp.value(val)

class Globe extends d3Object

    width = 310
    height = 310
    color = "#39f"

    constructor: () ->
        super "globe"

        @obj.attr("width", width)
        @obj.attr("height", height)

        @projection = d3.geo.orthographic()
                .scale(100)
                .translate([width/2, height/2])
                .rotate(0)
                .clipAngle(90)
        
        @path = d3.geo.path()
            .projection(@projection)

        @obj.append("path")
            .datum({type: "Sphere"})
            .attr("d", @path)
            .attr("stroke", color)

        @graticule = d3.geo.graticule()

        @obj.append("path")
            .datum(@graticule)
            .attr("d", @path)            
            .attr("stroke",color)

class Shell extends d3Object

    width = 310
    height = 310
    
    constructor: () ->
        super "shells"
        @data = [0, 0]

        @obj.attr("width", width)
        @obj.attr("height", height)

        shellArea = @obj.append("g")    
        shellArea.attr("width", width)
        shellArea.attr("height", height)
        shellArea.attr("id", "shellArea")

        @circles = shellArea.selectAll("circle")
            .data([100, 150])
            .enter()
            .append("circle")
            .attr("cx", width/2)
            .attr("cy", height/2)
            .attr("fill", "transparent")
            .attr("stroke-width","10")
            .attr("opacity", "0.75")
            .attr("r", (d) -> d) 

        @val(@data)
        
    initAxes: ->
        @c = d3.scale.linear()
            .domain([0, 500])
            .range(["black", "orangered"])

    val: (val) ->
        @data = val
        @circles.data @data
        @circles.attr("stroke", (d) => if d>0 then @c(d) else "transparent")


class Chart extends d3Object

    barWidth = 45
    margin = {top: 50, right: 10, bottom: 50, left: 10}
    width = 210 - margin.left - margin.right
    height = 300 - margin.top - margin.bottom
    colors = ["yellow", "red"]

    constructor: () ->
        super "chart"
        chartArea = @obj
        @data = [0, 0]
       
        chartArea.attr("width", width + margin.left + margin.right)
        chartArea.attr("height", height + margin.top + margin.bottom)
        chartArea.attr("class","chart")
        chartArea.attr("id", "chartArea")

        @plotArea = chartArea.append("g")
            .attr("transform", 
                "translate(" + margin.left + "," + margin.top + ")")
            .attr("id", "plotArea")
        
        @bars = @plotArea.selectAll("rect")
            .data([1..2])
            .enter()
            .append("rect")
            .attr("width", barWidth)
            .attr("x", (d,i) => i*barWidth)
            .attr("style", (d,i) -> "fill:"+colors[i])

        @val(@data)

        chartArea.append("g")
            .attr("transform", 
                "translate(" + (2*barWidth+20) + "," + margin.top + ")")
            .call(@yAxis) 

    initAxes: ->

        @y = d3.scale.linear()
            .domain([0, 400])
            .range([height, 0])

        @yAxis = d3.svg.axis()
            .scale(@y)
            .orient("right")

    val: (val) =>
        @data = val
        @bars.data @data
        @bars.attr("y", (d) => @y(d) )
            .attr("height", (d) => height - @y(d))


class Canvas

    @width = 960
    @height = 480
    
    @canvas = document.querySelector('canvas')
    @canvas.width = @width
    @canvas.height = @height
    @ctx = @canvas.getContext('2d')
    
    @clear: -> @ctx.clearRect(0, 0, @width, @height)
    
    @square: (pos, size, color) ->
        @ctx.fillStyle = color
        @ctx.fillRect(pos.x, pos.y, size, size)
    
class Vector

    z = -> new Vector

    constructor: (@x=0, @y=0) ->
        
    add: (v=z()) ->
        @x += v.x
        @y += v.y
        this
    
    mag: () -> Math.sqrt(@x*@x + @y*@y)
        
    ang: () -> Math.atan2(@y, @x)
        
    polar: (m, a) ->
        @x = m*Math.cos(a)
        @y = m*Math.sin(a)
        this

#==== Particles ====

class Photon

    # Set these in subclasses
    colors: ["#ff0", "#ff0", "#ff0", "#ff0"]
    sizes: [2, 4, 4, 4]
    
    w: Canvas.width
    h: Canvas.height

    O: -> new Vector 0, 0

    constructor: (@pos=@O(), @vel0=@O(), albedo, transmission, @limit=0) ->
        @velocity = []  # Set of velocities indexed by state
        @setVelocities()  # Configured in subclass
        @d = 0
        @setState 0
        @setBounce albedo, transmission

    setState: (@state) ->
        return if @state<0
        @vel = @velocity[@state]
        @color = @colors[@state]
        @size = @sizes[@state]

    setBounce: (albedo, transmission) ->
        X = Math.random()
        @bounce = X < albedo
        @transmit = albedo <= X < (albedo + transmission)
        @absorb = (albedo + transmission) <= X

    mod: (albedo, transmission) ->
        @setBounce albedo, transmission if @state is 0
        
    visible: ->
        (0 < @pos.x < @w) and (0 < @pos.y < @h) and @vel.mag() > 0
        
    draw: ->
        Canvas.square @pos, @size, @color

    move: ->
        if @collision() and @state is 0
            if @bounce then @setState(1)
            if @absorb then @setState(2)
            if @transmit then @setState(3)
        
        @d += @vel.mag()
        @pos.add @vel

class Sunlight extends Photon
    
    colors: ["#ff0", "#00f", "#000", "#000"]
    sizes: [2, 3, 3, 3]

    setVelocities: ->
        rad = 100
        cy = @h/2  # Canvas center
        @velocity[0] = new Vector @vel0.x, @vel0.y
        theta = Math.asin((@pos.y - cy)/rad) 
        @velocity[1] = (new Vector).polar(@vel0.mag(), pi-2*theta)        
        @velocity[2] = @O()
        @velocity[3] = new Vector @vel0.x, @vel0.y
        @limit = @w/2 - Math.sqrt(rad*rad-(@pos.y-cy)*(@pos.y-cy))
 
    collision: -> @pos.x > @limit
 

class InfraredEarth extends Photon
    
    colors: ["#f00", "#f00", "#f00", "#f00"]
    sizes: [3, 3, 3, 3]

    setVelocities: ->
        @velocity[0] = new Vector @vel0.x, @vel0.y
        @velocity[1] = @O()
        @velocity[2] = @O()
        @velocity[3] = @velocity[0]
    
    collision: -> @d > @limit

class InfraredAtmos extends Photon
    
    colors: ["#0f0", "#0f0", "#0f0", "#0f0"]
    sizes: [4, 4, 4, 4]

    setVelocities: ->
        @velocity[0] = new Vector @vel0.x, @vel0.y
        @velocity[1] = @O()
        @velocity[2] = @O()
        @velocity[3] = @O()
    
    collision: -> @d > @limit

#==== Emitters ====

class Emitter

    maxPhotons: 4000
    rate: 0
    checked: true
    
    cy: Canvas.height/2  # Canvas center
    
    constructor: ->
        @photons = []

    mod: (@albedo, @transmission) -> 
            photon.mod(@albedo, @transmission) for photon in @photons
            
    emit: (@albedo, @transmission) ->
        unless @photons.length > @maxPhotons
            # emitPhoton defined in subclass
            @photons.push(@emitPhoton()) for [0...@rate]
        @photons = @photons.filter (photon) => photon.visible()
        for photon in @photons
            photon.move()
            if @checked then photon.draw()

class Sun extends Emitter

    x: 1
    l: 200
    
    constructor: ->
        @velocity = new Vector 2, 0
        super()

    emitPhoton: ->
        pos = new Vector @x, @cy + @l*(Math.random()-0.5) 
        new Sunlight(pos, @velocity, @albedo, @transmission)

class Earth extends Emitter

    R: 100
    dist: Canvas.width/2

    emitPhoton: ->
        theta = Math.random()*2*pi
        surf = (new Vector).polar @R, theta
        pos = (new Vector @dist, @cy).add surf
        vel = (new Vector).polar 2, surf.ang()
        new InfraredEarth(pos, vel, @albedo, @transmission, 50)
 
class AtmosUp extends Emitter

    R: 150
    dist: Canvas.width/2

    emitPhoton: ->
        theta = Math.random()*2*pi
        surf = (new Vector).polar @R, theta
        pos = (new Vector @dist, @cy).add surf
        vel = (new Vector).polar 2, surf.ang()
        new InfraredAtmos(pos, vel, @albedo, @transmission, 5000)

class AtmosDn extends Emitter

    R: 150
    dist: Canvas.width/2

    emitPhoton: ->
        theta = Math.random()*2*pi
        surf = (new Vector).polar @R, theta
        pos = (new Vector @dist, @cy).add surf
        vel = (new Vector).polar 2, surf.ang() + pi
        new InfraredAtmos(pos, vel, @albedo, @transmission, 50)

#==== Simulation ====
 
class Simulation

    constructor: ->

        @sunValToRate = d3.scale.linear()
            .rangeRound([0,16])
            .domain([0, 2048])
        @fluxToRate = d3.scale.linear()
            .rangeRound([0,16])
            .domain([0, 500])

        @sun = new Sun
        @earth = new Earth
        @atmosUp = new AtmosUp
        @atmosDn = new AtmosDn
        @bars = new Chart
        @shell = new Shell
        @globe = new Globe
        @temperature = new Display
        @sunOn = new Checkbox "sunOn" , (v) =>  @sun.checked = v
        @earthOn = new Checkbox "earthOn" , (v) =>  @earth.checked = v
        @atmosOn = new Checkbox "atmosOn" , 
            (v) =>  
                @atmosUp.checked = v
                @atmosDn.checked = v

        # sun -> earth propagation delay
        @delayStart = (@earth.dist-@earth.R)/@sun.velocity.mag()
        @sunCounter = @delayStart 

        # sliders
        @albedo = new Slider "albedo", (v) => @sun.mod(v, 0)
        @insolation = new Slider "insolation", 
            (v) => 
                @sun.rate = @sunValToRate(v)
                @nextInsol = v
                @sunCounter = @delayStart
        @co2 = new Slider "co2" , (v) ->  v

        # Initialize
        @setParams(1366, 0, 0, 'checked', 'checked', 'checked')
        @sun.rate = @sunValToRate(@insolation.val())
        @albedo.sliderDisp.html(@albedo.val())
        @insolation.sliderDisp.html(@insolation.val())
        @co2.sliderDisp.html(@co2.val())

        # For computation, sun is initially off
        @insol = 0
        @nextInsol = @insolation.val()
        
        # ODE
        @si = 5.67e-8 # $W/m^2/K^4$
        @C = 14 # $W years/ m^2 K$ <a href="http://www.ecd.bnl.gov/steve/pubs/HeatCapacity.pdf">Earth's heat capacity</a>
        @inSun = (ap, S) -> 0.25*(1-ap)*S
        @inAtmos = (y, si, ep) -> si*(ep/2)*y.pow(4)
        @outEarth = (y, si) -> si*y.pow(4)
        @y = 0
        @h = 0.5
        @decimationCounter = 0

    start: () ->
        setTimeout (=> @animate 20000), 200
        
    snapshot: () ->
        Canvas.clear()
        
        if @sunCounter > 0 then @sunCounter -=1
        if @sunCounter == 0 then @insol = @nextInsol

        @decimationCounter +=1
        @decimationCounter = @decimationCounter % 5

        if @decimationCounter == 0
            Isun = @inSun @albedo.val(), @insol
            Iatmos = @inAtmos @y, @si, @co2.val()
            Iearth = @outEarth @y, @si
            @y += @h*1/@C*(Isun - (Iearth - Iatmos))

            @earth.rate = @fluxToRate(Iearth)
            @atmosUp.rate = @fluxToRate(Iatmos)
            @atmosDn.rate = @fluxToRate(Iatmos)
            @bars.val([Isun, (Iearth - Iatmos)])
            @shell.val([Iearth, Iatmos*2]) # Atmos x2 for visibility

        @sun.emit(@albedo.val(), 0)
        @earth.emit(0, 1-@co2.val())
        @atmosUp.emit(0, 0)
        @atmosDn.emit(0, 0)
        
        @temperature.val @y-273.15

    animate: () ->
        @timer = setInterval (=> @snapshot()), 50
        
    stop: ->
        clearInterval @timer
        @timer = null

    setParams: (ins, alb, eps, sun, earth, atmos) ->
        $("#insolation").val(ins)
        $("#albedo").val(alb)
        $("#co2").val(eps)
        $("#sunOn").attr('checked', sun)
        $("#earthOn").attr('checked', earth)
        $("#atmosOn").attr('checked', atmos)
        $("#insolation").trigger("change")
        $("#albedo").trigger("change")
        $("#co2").trigger("change")

class Slider

    constructor: (@id, @change) ->
        @slider = $ "##{id}"
        @sliderDisp = $ "##{id}-value"
        @slider.unbind()  # needed to clear event handlers
        @slider.on "change", =>
            val = @val()
            @change val
            @sliderDisp.html(val)
        
    val: -> @slider.val()

class Checkbox

    constructor: (@id, @change) ->
        @checkbox = $ "##{id}"
        @checkbox.unbind()  # needed to clear event handlers
        @checkbox.on "change", =>
            val = @val()
            @change val
        
    val: -> @checkbox.is(":checked")


sim = new Simulation

# Set parameters from text.

$("#params1").on "click", => 
    sim.stop()
    sim = new Simulation
    sim.start()
$("#params2a").on "click", => 
    sim.setParams(1366, 0.3, 0, "checked", "checked", "checked")
$("#params3").on "click", => 
    sim.setParams(1366, 0.3, 0.78, "checked", "checked", "checked")
$("#params4").on "click", => 
    sim.setParams(1366, 0.3, 0.82, "checked", "checked", "checked")
$("#params4b").on "click", =>
    sim.stop()

setTimeout (-> sim.start()), 2000


