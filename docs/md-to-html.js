const CONFIG = {
    repoBase: "https://raw.githubusercontent.com/frontier-org/frontier/main/",
    defaultFile: "README.md",
    navbarHeight: 90 
};

const DOCS_WHITELIST = [
    "README.md",
    "LOGS.md",
    "MANUAL.md",
    "ROADMAP.md"
];

const renderer = new marked.Renderer();

renderer.heading = ({ text, depth }) => {
    const slug = text.toLowerCase()
        .replace(/<[^>]*>/g, '') 
        .replace(/[^\w\s-]/g, '') 
        .replace(/\s/g, '-');
    return `<h${depth} id="${slug}">${text}</h${depth}>`;
};

renderer.link = (data) => {
    const { href, text } = data;
    if (!href) return text;
    if (href.startsWith('http')) return `<a href="${href}" target="_blank" rel="noopener">${text}</a>`;

    if (href.endsWith('.md') || href.includes('.md#')) {
        const [file, anchor] = href.replace('./', '').split('#');
        if (DOCS_WHITELIST.includes(file)) {
            return `<a href="./?${file}${anchor ? '#' + anchor : ''}">${text}</a>`;
        }
    }
    return `<a href="${href}">${text}</a>`;
};

renderer.image = (data) => {
    const { href, text } = data;
    if (!href) return text;
    if (!href.startsWith('http')) {
        const cleanPath = href.replace('./', '');
        return `<img src="${CONFIG.repoBase}${cleanPath}" alt="${text || ''}" class="rounded-xl border border-white/10 my-10 shadow-2xl max-w-full mx-auto">`;
    }
    return `<img src="${href}" alt="${text || ''}" class="rounded-xl border border-white/10 my-10 shadow-2xl max-w-full mx-auto">`;
};

marked.use({ renderer });

function scrollToAnchor() {
    const hash = window.location.hash;
    if (hash) {
        const targetId = decodeURIComponent(hash.substring(1));
        const element = document.getElementById(targetId);
        if (element) {
            const elementPosition = element.getBoundingClientRect().top + window.pageYOffset;
            window.scrollTo({ top: elementPosition - CONFIG.navbarHeight, behavior: "smooth" });
        }
    }
}

async function loadContent() {
    const queryString = window.location.search.substring(1);
    const fileName = queryString.split('#')[0] || CONFIG.defaultFile;
    const targetFile = fileName.startsWith('./') ? fileName.substring(2) : fileName;

    const contentEl = document.getElementById('content');
    const headerEl = document.getElementById('doc-header');
    const loadingBody = document.getElementById('loading-body');

    try {
        if (!DOCS_WHITELIST.includes(targetFile)) {
            throw new Error("UNAUTHORIZED_FILE");
        }

        const cacheBuster = `?t=${new Date().getTime()}`;
        const response = await fetch(CONFIG.repoBase + targetFile + cacheBuster, { cache: "no-cache" });
        
        if (!response.ok) throw new Error(`404`);

        const markdown = await response.text();
        contentEl.innerHTML = marked.parse(markdown);

        const firstH1 = contentEl.querySelector('h1');
        if (firstH1) {
            headerEl.innerHTML = `
                <div class="text-cyan-500 font-bold text-sm tracking-widest uppercase mb-4 flex items-center gap-2">
                    <i class="fas fa-file-alt"></i> docs/${targetFile}
                </div>
                <h1 class="text-5xl md:text-7xl font-black tracking-tighter text-white">
                    ${firstH1.innerText}
                </h1>
            `;
            firstH1.remove();
        }

        contentEl.querySelectorAll('pre code').forEach((block) => {
            hljs.highlightElement(block);
        });

        loadingBody.classList.add('hidden');
        contentEl.classList.remove('hidden');
        document.title = `Frontier | ${targetFile}`;
        setTimeout(scrollToAnchor, 150);

    } catch (err) {
        console.error("Redirecting to 404 due to:", err.message);
        
        window.location.href = "/404.html";
    }
}

loadContent();
window.addEventListener('popstate', loadContent);
window.addEventListener('hashchange', scrollToAnchor);