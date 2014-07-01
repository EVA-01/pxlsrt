require 'rubygems'
require 'oily_png'

module Pxlsrt
	##
	# Smart sorting uses edge-finding algorithms to create bands to sort,
	# as opposed to brute sorting which doesn't care for the content or 
	# edges, just a specified range to create bands.
	class Smart
		##
		# Uses Pxlsrt::Smart.smart to input and output from pne method.
		def self.suite(inputFileName, outputFileName, o={})
			kml=Pxlsrt::Smart.smart(inputFileName, o)
			if Pxlsrt::Helpers.contented(kml)
				kml.save(outputFileName)
			end
		end
		##
		# The main attraction of the Smart class. Returns a ChunkyPNG::Image that is sorted according to the options provided. Will return nil if it encounters an errors.
		def self.smart(input, o={})
			startTime=Time.now
			defOptions={
				:reverse => "no",
				:vertical => false,
				:diagonal => false,
				:smooth => false,
				:method => "sum-rgb",
				:verbose => false,
				:absolute => false,
				:threshold => 20,
				:edge => 2,
				:trusted => false
			}
			defRules={
				:reverse => ["no", "reverse", "either"],
				:vertical => [false, true],
				:diagonal => [false, true],
				:smooth => [false, true],
				:method => ["sum-rgb", "red", "green", "blue", "sum-hsb", "hue", "saturation", "brightness", "uniqueness", "luma", "random"],
				:verbose => [false, true],
				:absolute => [false, true],
				:threshold => [{:class => [Float, Fixnum]}],
				:edge => [{:class => [Fixnum]}],
				:trusted => [false, true]
			}
			options=defOptions.merge(o)
			if o.length==0 or o[:trusted]==true or (o[:trusted]==false and o.length!=0 and Pxlsrt::Helpers.checkOptions(options, defRules)!=false)
				Pxlsrt::Helpers.verbose("Options are all good.") if options[:verbose]
				if input.class==String
					Pxlsrt::Helpers.verbose("Getting image from file...") if options[:verbose]
					if File.file?(input)
						if Pxlsrt::Colors.isPNG?(input)
							input=ChunkyPNG::Image.from_file(input)
						else
							Pxlsrt::Helpers.error("File #{input} is not a valid PNG.") if options[:verbose]
							return
						end
					else
						Pxlsrt::Helpers.error("File #{input} doesn't exist!") if options[:verbose]
						return
					end
				elsif input.class!=String and input.class!=ChunkyPNG::Image
					Pxlsrt::Helpers.error("Input is not a filename or ChunkyPNG::Image") if options[:verbose]
					return
				end
				Pxlsrt::Helpers.verbose("Smart mode.") if options[:verbose]
				case options[:reverse].downcase
					when "reverse"
						nre=1
					when "either"
						nre=-1
					else
						nre=0
				end
				img=input
				w,h=img.width,img.height
				sobel_x = [[-1,0,1], [-2,0,2], [-1,0,1]]
				sobel_y = [[-1,-2,-1], [ 0, 0, 0], [ 1, 2, 1]]
				edge = ChunkyPNG::Image.new(w, h, ChunkyPNG::Color::TRANSPARENT)
				valued="start"
				k=[]
				Pxlsrt::Helpers.verbose("Getting Sobel values and colors for pixels...") if options[:verbose]
				for xy in 0..(w*h-1)
					x=xy % w
					y=(xy/w).floor
					if x!=0 and x!=(w-1) and y!=0 and y!=(h-1)
						pixel_x=(sobel_x[0][0]*Pxlsrt::Colors.sobelate(img,x-1,y-1))+(sobel_x[0][1]*Pxlsrt::Colors.sobelate(img,x,y-1))+(sobel_x[0][2]*Pxlsrt::Colors.sobelate(img,x+1,y-1))+(sobel_x[1][0]*Pxlsrt::Colors.sobelate(img,x-1,y))+(sobel_x[1][1]*Pxlsrt::Colors.sobelate(img,x,y))+(sobel_x[1][2]*Pxlsrt::Colors.sobelate(img,x+1,y))+(sobel_x[2][0]*Pxlsrt::Colors.sobelate(img,x-1,y+1))+(sobel_x[2][1]*Pxlsrt::Colors.sobelate(img,x,y+1))+(sobel_x[2][2]*Pxlsrt::Colors.sobelate(img,x+1,y+1))
						pixel_y=(sobel_y[0][0]*Pxlsrt::Colors.sobelate(img,x-1,y-1))+(sobel_y[0][1]*Pxlsrt::Colors.sobelate(img,x,y-1))+(sobel_y[0][2]*Pxlsrt::Colors.sobelate(img,x+1,y-1))+(sobel_y[1][0]*Pxlsrt::Colors.sobelate(img,x-1,y))+(sobel_y[1][1]*Pxlsrt::Colors.sobelate(img,x,y))+(sobel_y[1][2]*Pxlsrt::Colors.sobelate(img,x+1,y))+(sobel_y[2][0]*Pxlsrt::Colors.sobelate(img,x-1,y+1))+(sobel_y[2][1]*Pxlsrt::Colors.sobelate(img,x,y+1))+(sobel_y[2][2]*Pxlsrt::Colors.sobelate(img,x+1,y+1))
						val = Math.sqrt(pixel_x * pixel_x + pixel_y * pixel_y).ceil
					else
						val = 2000000000
					end
					k.push({ "sobel" => val, "pixel" => [x, y], "color" => Pxlsrt::Colors.getRGB(img[x, y]) })
				end
				if options[:vertical]==true
					Pxlsrt::Helpers.verbose("Rotating image for vertical mode...") if options[:verbose]
					k=Pxlsrt::Colors.rotateImage(k,w,h,3)
					w,h=h,w
				end
				if !options[:diagonal]
					lines=Pxlsrt::Colors.imageRGBLines(k, w)
					Pxlsrt::Helpers.verbose("Determining bands with a#{options[:absolute] ? "n absolute" : " relative"} threshold of #{options[:threshold]}...") if options[:verbose]
					bands=Array.new()
					for j in lines
						slicing=true
						pixel=0
						m=Array.new()
						while slicing do
							n=Array.new
							if m.length > 1
								while m.last.length < options[:edge]
									if m.length > 1
										m[-2].concat(m[-1])
										m.pop
									else
										break
									end
								end
							end
							bandWorking=true
							while bandWorking do
								n.push(j[pixel]["color"])
								if (options[:absolute] ? (j[pixel+1]["sobel"]) : (j[pixel+1]["sobel"]-j[pixel]["sobel"])) > options[:threshold]
									bandWorking=false
								end
								if (pixel+1)==(j.length-1)
									n.push(j[pixel+1]["color"])
									slicing=false
									bandWorking=false
								end
								pixel+=1
							end
							m.push(n)
						end
						bands.concat(m)
					end
					Pxlsrt::Helpers.verbose("Pixel sorting using method '#{options[:method]}'...") if options[:verbose]
					image=[]
					if options[:smooth]
						for band in bands
							u=band.group_by {|x| x}
							image.concat(Pxlsrt::Colors.pixelSort(u.keys, options[:method], nre).map { |x| u[x] }.flatten(1))
						end
					else
						for band in bands
							image.concat(Pxlsrt::Colors.pixelSort(band, options[:method], nre))
						end
					end
				else
					Pxlsrt::Helpers.verbose("Determining diagonals...") if options[:verbose]
					dia=Pxlsrt::Colors.getDiagonals(k,w,h)
					Pxlsrt::Helpers.verbose("Determining bands with a#{options[:absolute] ? "n absolute" : " relative"} threshold of #{options[:threshold]}...") if options[:verbose]
					for j in dia.keys
						bands=[]
						if dia[j].length>1
							slicing=true
							pixel=0
							m=Array.new()
							while slicing do
								n=Array.new
								if m.length > 1
									while m.last.length < options[:edge]
										if m.length > 1
											m[-2].concat(m[-1])
											m.pop
										else
											break
										end
									end
								end
								bandWorking=true
								while bandWorking do
									n.push(dia[j][pixel]["color"])
									if (options[:absolute] ? (dia[j][pixel+1]["sobel"]) : (dia[j][pixel+1]["sobel"]-dia[j][pixel]["sobel"])) > options[:threshold]
										bandWorking=false
									end
									if (pixel+1)==(dia[j].length-1)
										n.push(dia[j][pixel+1]["color"])
										slicing=false
										bandWorking=false
									end
									pixel+=1
								end
								m.push(n)
							end
						else
							m=[[dia[j].first["color"]]]
						end
						dia[j]=bands.concat(m)
					end
					Pxlsrt::Helpers.verbose("Pixel sorting using method '#{options[:method]}'...") if options[:verbose]
					for j in dia.keys
						ell=[]
						if options[:smooth]
							for band in dia[j]
								u=band.group_by {|x| x}
								ell.concat(Pxlsrt::Colors.pixelSort(u.keys, options[:method], nre).map { |x| u[x] }.flatten(1))
							end
						else
							for band in dia[j]
								ell.concat(Pxlsrt::Colors.pixelSort(band, options[:method], nre))
							end
						end
						dia[j]=ell
					end
					Pxlsrt::Helpers.verbose("Setting diagonals back to standard lines...") if options[:verbose]
					image=Pxlsrt::Colors.fromDiagonals(dia,w)
				end
				if options[:vertical]==true
					Pxlsrt::Helpers.verbose("Rotating back (because of vertical mode).") if options[:verbose]
					image=Pxlsrt::Colors.rotateImage(image,w,h,1)
					w,h=h,w
				end
				Pxlsrt::Helpers.verbose("Giving pixels new RGB values...") if options[:verbose]
				for px in 0..(w*h-1)
					edge[px % w, (px/w).floor]=Pxlsrt::Colors.arrayToRGB(image[px])
				end
				endTime=Time.now
				timeElapsed=endTime-startTime
				if timeElapsed < 60
					Pxlsrt::Helpers.verbose("Took #{timeElapsed.round(4)} second#{ timeElapsed.round(4)!=1.0 ? "s" : "" }.") if options[:verbose]
				else
					minutes=(timeElapsed/60).floor
					seconds=(timeElapsed % 60).round(4)
					Pxlsrt::Helpers.verbose("Took #{minutes} minute#{ minutes!=1 ? "s" : "" } and #{seconds} second#{ seconds!=1.0 ? "s" : "" }.") if options[:verbose]
				end
				Pxlsrt::Helpers.verbose("Returning ChunkyPNG::Image...") if options[:verbose]
				return edge
			else
				Pxlsrt::Helpers.error("Options specified do not follow the correct format.") if options[:verbose]
				return
			end
		end
	end
end