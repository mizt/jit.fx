#import <string>
#import "../Plugin.h"

namespace FX {
	
	class Object : public FX::Base {
		
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
					
					unsigned int *src = (unsigned int *)(bip+i*in_rows);
					unsigned int *dst = (unsigned int *)(bop+i*out_rows);
					
					for(long j=0; j<width; j++) {
						
						unsigned int tmp = *src++; 

#ifdef EMSCRIPTEN	

						unsigned char a = (tmp>>24)&0xFF;
						unsigned char r = (tmp)&0xFF;
						unsigned char g = (tmp>>8)&0xFF;
						unsigned char b = (tmp>>16)&0xFF;

#else						
						unsigned char b = (tmp>>24)&0xFF;
						unsigned char g = (tmp>>16)&0xFF;
						unsigned char r = (tmp>>8)&0xFF;
						unsigned char a = (tmp)&0xFF;
												
#endif		

						r*=this->gain;
						g*=this->gain;
						b*=this->gain;
						

#ifdef EMSCRIPTEN	
						*dst++ = a<<24|b<<16|g<<8|r;
#else						
						*dst++ = b<<24|g<<16|r<<8|a;
#endif		
			
					}
				}
				
			}			
	};
}

#ifdef EMSCRIPTEN

	static const void *instance = (void *)(new FX::Object(nullptr));	

	extern "C" void set(std::string key,double vale) {
		((FX::Object *)instance)->set(key,vale);	
	}

	extern "C" void calc(long *dim,unsigned char *bip,long in_rows,unsigned char *bop, long out_rows) {
		((FX::Object *)instance)->calc(dim,bip,in_rows,bop,out_rows);	
	}

#else

	Plugin::Plugin(POST_FUNC func) {	
		this->instance = (void *)(new FX::Object(func));	
	}

	Plugin::~Plugin() {
		delete (FX::Object *)this->instance;
	}

	void Plugin::set(std::string key,double vale) {
		((FX::Object *)this->instance)->set(key,vale);	
	}

	void Plugin::calc(long *dim,unsigned char *bip,long in_rows,unsigned char *bop, long out_rows) {
		((FX::Object *)this->instance)->calc(dim,bip,in_rows,bop,out_rows);	
	}
	
	extern "C" Plugin *newPlugin(POST_FUNC func) { return new Plugin(func); }
	extern "C" void deletePlugin(Plugin *plugin) { delete plugin; }

#endif