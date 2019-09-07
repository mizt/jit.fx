#import <Cocoa/Cocoa.h>
#import <string>
#import "../Plugin.h"

namespace FX {
	
	class Object : public Base {
		
		private:
		
			double gain = 1.0;

		public:
			
			Object(POST_FUNC func) : Base(func) {
				//post("FX");
			}
			~Object() {
			}
			void set(std::string key,double value) {
				if(key=="gain") {
					//post("%s = %f",(char *)key.c_str(),value);					
					this->gain = value;
					if(this->gain<0) this->gain = 0;
					else if(this->gain>=1) this->gain = 1;
				}			
			}
			
			void calc(long *dim,unsigned char *bip,long in_rows,unsigned char *bop, long out_rows) { 
				
				long width  = dim[0];
				long height = dim[1];
				
				for(long i=0;i<height;i++) {
					
					unsigned char *src = bip+i*in_rows;
					unsigned char *dst = bop+i*out_rows;
					
					for(long j=0; j<width; j++) {
						
						*dst++ = *src++;
						
						unsigned char r = *src++;
						unsigned char g = *src++;
						unsigned char b = *src++;
						
						*dst++ = (r)*this->gain;
						*dst++ = (g)*this->gain;
						*dst++ = (b)*this->gain;
						
					}
				}
			}			
	};
}

Plugin::Plugin(POST_FUNC func) {	
	this->instance = (void *)(new FX::Object(func));	
}

Plugin::~Plugin() {
	delete (FX::Object *)this->instance;
}

void Plugin::set(std::string key,double vale) {
	((FX::Object *)this->instance)->set(key,vale);	
}

void Plugin::calc(long *dim,unsigned char  *bip,long in_rows,unsigned char  *bop, long out_rows) {
	((FX::Object *)this->instance)->calc(dim,bip,in_rows,bop,out_rows);	
}

extern "C" Plugin *newPlugin(POST_FUNC func) { return new Plugin(func); }
extern "C" void deletePlugin(Plugin *plugin) { delete plugin; }