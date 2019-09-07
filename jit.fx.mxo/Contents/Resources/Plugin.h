typedef void (*POST_FUNC)(const char *fmt, ...);

class Plugin {
	private:
		void *instance = nullptr;
	public:	
		Plugin(POST_FUNC func);
		~Plugin();
		virtual void set(std::string key,double value);
        virtual void calc(long *dim,unsigned char *bip,long in_rows,unsigned char *bop, long out_rows);
};

#ifdef USE_PLUGIN
	typedef Plugin *newPlugin(POST_FUNC func);
	typedef void deletePlugin(Plugin*);
#else

namespace FX {
	class Base {
		public:
			POST_FUNC _post = nullptr;	
			template<typename ...Args>
			void post(const char* format,Args ...args){
				(*this->_post)(format,std::forward<Args>(args)...);
			}			
			Base(POST_FUNC func) {
				this->_post = func;
			}		
			~Base() {
				this->_post = nullptr;
			}
	};
}

#endif